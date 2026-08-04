import 'dart:convert';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../core/startup_profiler.dart';
import '../../models/holiday.dart';
import '../../models/todo.dart';

class PendingTodoChange {
  const PendingTodoChange({
    required this.rowId,
    required this.todoId,
    required this.operation,
    required this.payload,
    required this.createdAt,
    this.batchId,
    required this.operationId,
  });

  final int rowId;
  final int todoId;
  final String operation;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final String? batchId;
  final String operationId;
}

class PendingUploadBatch {
  const PendingUploadBatch({
    required this.batchId,
    required this.changes,
    required this.createdAt,
    required this.attemptCount,
  });

  final String batchId;
  final List<PendingTodoChange> changes;
  final DateTime createdAt;
  final int attemptCount;
}

class LocalTodoMutation {
  const LocalTodoMutation({required this.action, this.todo, this.todoId});

  final String action;
  final Todo? todo;
  final int? todoId;
}

class LocalTodoDatabase {
  Future<Database>? _databaseFuture;

  Future<Database> get _db => _databaseFuture ??= _open();

  Future<Database> _open() async {
    StartupProfiler.mark('sqlite_open_start');
    final root = await getDatabasesPath();
    final database = await openDatabase(
      p.join(root, 'skechat_local.db'),
      version: 3,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE todos (
            id INTEGER PRIMARY KEY,
            date_key TEXT NOT NULL,
            payload TEXT NOT NULL,
            is_deleted INTEGER NOT NULL DEFAULT 0,
            server_updated_at TEXT
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_todos_date_deleted ON todos(date_key, is_deleted)',
        );
        await db.execute('''
          CREATE TABLE sync_outbox (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            todo_id INTEGER NOT NULL,
            operation_id TEXT NOT NULL UNIQUE,
            batch_id TEXT,
            operation TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE UNIQUE INDEX idx_sync_outbox_unbatched_todo
          ON sync_outbox(todo_id) WHERE batch_id IS NULL
        ''');
        await _createSyncBatchTable(db);
        await db.execute('''
          CREATE TABLE sync_meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await _createHolidayTable(db);
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) await _createHolidayTable(db);
        if (oldVersion < 3) await _upgradeSyncOutbox(db);
      },
    );
    StartupProfiler.mark('sqlite_open_end');
    return database;
  }

  Future<void> close() async {
    final databaseFuture = _databaseFuture;
    _databaseFuture = null;
    if (databaseFuture == null) return;
    final database = await databaseFuture;
    await database.close();
  }

  Future<List<Todo>> todosForDate(DateTime date) async {
    final db = await _db;
    final rows = await db.query(
      'todos',
      columns: ['payload'],
      where: 'date_key = ? AND is_deleted = 0',
      whereArgs: [_dateKey(date)],
      orderBy: 'json_extract(payload, \'\$.eta\') ASC',
    );
    return rows.map(_todoFromRow).toList(growable: false);
  }

  Future<List<Todo>> deletedTodos() async {
    final db = await _db;
    final rows = await db.query(
      'todos',
      columns: ['payload'],
      where: 'is_deleted = 1',
      orderBy: 'server_updated_at DESC, id DESC',
    );
    return rows.map(_todoFromRow).toList(growable: false);
  }

  Future<Todo> createTodo(Todo draft) async {
    final db = await _db;
    return db.transaction((txn) async {
      final id = await _nextTemporaryId(txn);
      final todo = draft.copyWith(id: id);
      await _writeTodo(txn, todo, isDeleted: false);
      await _queue(txn, id, 'create', _offlinePayload(todo));
      return todo;
    });
  }

  Future<List<Todo>> applyMutations(List<LocalTodoMutation> mutations) async {
    final db = await _db;
    return db.transaction((txn) async {
      final results = <Todo>[];
      for (final mutation in mutations) {
        switch (mutation.action) {
          case 'create':
            final draft = mutation.todo!;
            final id = await _nextTemporaryId(txn);
            final todo = draft.copyWith(id: id);
            await _writeTodo(txn, todo, isDeleted: false);
            await _queue(txn, id, 'create', _offlinePayload(todo));
            results.add(todo);
            continue;
          case 'update':
            final todo = mutation.todo!;
            await _findTodo(txn, todo.id);
            await _writeTodo(txn, todo, isDeleted: false);
            final existing = await _pendingForTodo(txn, todo.id);
            await _queue(
              txn,
              todo.id,
              existing?.operation == 'create' ? 'create' : 'update',
              _offlinePayload(todo),
            );
            results.add(todo);
            continue;
          case 'delete':
            final id = mutation.todoId!;
            final todo = await _findTodo(txn, id);
            await _writeTodo(txn, todo, isDeleted: true);
            final existing = await _pendingForTodo(txn, id);
            if (id < 0 && existing?.operation == 'create') {
              await _removePendingForTodo(txn, id);
            } else {
              await _queue(
                txn,
                id,
                'delete',
                existing?.payload ?? const <String, dynamic>{},
              );
            }
            results.add(todo);
            continue;
          default:
            throw ArgumentError.value(
              mutation.action,
              'action',
              'Unsupported local CRUD action',
            );
        }
      }
      return results;
    });
  }

  Future<Todo> updateTodo(Todo todo) async {
    final db = await _db;
    return db.transaction((txn) async {
      await _findTodo(txn, todo.id);
      await _writeTodo(txn, todo, isDeleted: false);
      final existing = await _pendingForTodo(txn, todo.id);
      await _queue(
        txn,
        todo.id,
        existing?.operation == 'create' ? 'create' : 'update',
        _offlinePayload(todo),
      );
      return todo;
    });
  }

  Future<Todo> setCompleted(int id, bool completed) async {
    final db = await _db;
    return db.transaction((txn) async {
      final todo = await _findTodo(txn, id);
      final updated = todo.copyWith(isCompleted: completed);
      await _writeTodo(txn, updated, isDeleted: false);
      final existing = await _pendingForTodo(txn, id);
      if (existing?.operation == 'create') {
        await _queue(txn, id, 'create', _offlinePayload(updated));
        return updated;
      }
      final operation = existing?.operation == 'restore' ? 'restore' : 'update';
      await _queue(txn, id, operation, <String, dynamic>{
        'is_completed': completed,
      });
      return updated;
    });
  }

  Future<void> deleteTodo(int id) async {
    final db = await _db;
    await db.transaction((txn) async {
      final todo = await _findTodo(txn, id);
      await _writeTodo(txn, todo, isDeleted: true);
      final existing = await _pendingForTodo(txn, id);
      if (id < 0 && existing?.operation == 'create') {
        await _removePendingForTodo(txn, id);
        return;
      }
      if (existing?.operation == 'restore') {
        await _removePendingForTodo(txn, id);
      } else {
        await _queue(
          txn,
          id,
          'delete',
          existing?.payload ?? const <String, dynamic>{},
        );
      }
    });
  }

  Future<Todo> restoreTodo(int id) async {
    final db = await _db;
    return db.transaction((txn) async {
      final todo = await _findTodo(txn, id);
      await _writeTodo(txn, todo, isDeleted: false);
      final existing = await _pendingForTodo(txn, id);
      if (id < 0) {
        if (existing?.operation == 'delete') {
          await _removePendingForTodo(txn, id);
          return todo;
        }
        await _queue(txn, id, 'create', _offlinePayload(todo));
        return todo;
      }
      if (existing?.operation == 'delete') {
        if (existing!.payload.isEmpty) {
          await _removePendingForTodo(txn, id);
        } else {
          await _queue(txn, id, 'update', existing.payload);
        }
      } else {
        await _queue(txn, id, 'restore', const <String, dynamic>{});
      }
      return todo;
    });
  }

  Future<List<PendingTodoChange>> pendingChanges() async {
    final db = await _db;
    final rows = await db.query('sync_outbox', orderBy: 'id ASC');
    return rows.map(_pendingFromRow).toList(growable: false);
  }

  Future<void> removePendingChange(int rowId) async {
    final db = await _db;
    await db.delete('sync_outbox', where: 'id = ?', whereArgs: [rowId]);
  }

  Future<PendingUploadBatch?> prepareUploadBatch(int limit) async {
    final db = await _db;
    return db.transaction((txn) async {
      final active = await txn.query(
        'sync_batches',
        where: 'status = ?',
        whereArgs: ['PENDING'],
        orderBy: 'created_at ASC',
        limit: 1,
      );
      String batchId;
      DateTime createdAt;
      int attemptCount;
      if (active.isNotEmpty) {
        batchId = active.single['batch_id']! as String;
        createdAt = DateTime.parse(active.single['created_at']! as String);
        attemptCount = active.single['attempt_count']! as int;
      } else {
        final candidates = await txn.query(
          'sync_outbox',
          columns: ['id'],
          where: 'batch_id IS NULL',
          orderBy: 'id ASC',
          limit: limit,
        );
        if (candidates.isEmpty) return null;
        batchId = _uuidV4();
        createdAt = DateTime.now().toUtc();
        attemptCount = 0;
        final ids = candidates.map((row) => row['id']! as int).toList();
        final placeholders = List.filled(ids.length, '?').join(',');
        await txn.rawUpdate(
          'UPDATE sync_outbox SET batch_id = ? WHERE id IN ($placeholders)',
          [batchId, ...ids],
        );
        await txn.insert('sync_batches', <String, Object?>{
          'batch_id': batchId,
          'status': 'PENDING',
          'operation_count': ids.length,
          'attempt_count': 0,
          'created_at': createdAt.toIso8601String(),
        });
      }
      final rows = await txn.query(
        'sync_outbox',
        where: 'batch_id = ?',
        whereArgs: [batchId],
        orderBy: 'id ASC',
      );
      return PendingUploadBatch(
        batchId: batchId,
        changes: rows.map(_pendingFromRow).toList(growable: false),
        createdAt: createdAt,
        attemptCount: attemptCount,
      );
    });
  }

  Future<void> recordBatchAttempt(String batchId) async {
    final db = await _db;
    await db.rawUpdate(
      '''
      UPDATE sync_batches
      SET attempt_count = attempt_count + 1, last_attempt_at = ?
      WHERE batch_id = ?
    ''',
      [DateTime.now().toUtc().toIso8601String(), batchId],
    );
  }

  Future<void> applyCommittedBatch(
    PendingUploadBatch batch,
    List<Map<String, dynamic>> results,
  ) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final change in batch.changes) {
        final result = results.singleWhere(
          (item) => item['operation_id'] == change.operationId,
        );
        if (change.operation == 'create') {
          final remoteId = result['todo_id']! as int;
          final currentRows = await txn.query(
            'todos',
            where: 'id = ?',
            whereArgs: [change.todoId],
            limit: 1,
          );
          if (currentRows.isNotEmpty) {
            final current = _todoFromRow(
              currentRows.single,
            ).copyWith(id: remoteId);
            final wasDeleted = currentRows.single['is_deleted'] == 1;
            await _writeTodo(txn, current, isDeleted: wasDeleted);
            await txn.delete(
              'todos',
              where: 'id = ?',
              whereArgs: [change.todoId],
            );
          }
          await txn.update(
            'sync_outbox',
            {'todo_id': remoteId},
            where: 'todo_id = ? AND batch_id IS NULL',
            whereArgs: [change.todoId],
          );
        }
        await txn.delete(
          'sync_outbox',
          where: 'id = ? AND batch_id = ?',
          whereArgs: [change.rowId, batch.batchId],
        );
      }
      await txn.delete(
        'sync_batches',
        where: 'batch_id = ?',
        whereArgs: [batch.batchId],
      );
    });
  }

  Future<void> replaceCreatedTodo(
    int pendingRowId,
    int temporaryId,
    Todo remoteTodo,
  ) async {
    final db = await _db;
    await db.transaction((txn) async {
      await _writeTodo(txn, remoteTodo, isDeleted: false);
      await txn.delete('todos', where: 'id = ?', whereArgs: [temporaryId]);
      await txn.delete(
        'sync_outbox',
        where: 'id = ?',
        whereArgs: [pendingRowId],
      );
    });
  }

  Future<int> pendingCount() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM sync_outbox',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<DateTime?> latestPendingChangeAt() async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT MAX(created_at) AS latest FROM sync_outbox',
    );
    final value = rows.single['latest'] as String?;
    return value == null ? null : DateTime.parse(value);
  }

  Future<String?> syncCursor() async {
    final db = await _db;
    final rows = await db.query(
      'sync_meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['schedule_cursor'],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['value']! as String;
  }

  Future<String?> holidaySyncCursor() => _metaValue('holiday_cursor');

  Future<List<AppHoliday>> holidays({String countryCode = 'KR'}) async {
    final db = await _db;
    final rows = await db.query(
      'holidays',
      where: 'country_code = ? AND is_deleted = 0',
      whereArgs: [countryCode],
      orderBy: 'date_key ASC',
    );
    return rows
        .map(
          (row) => AppHoliday(
            countryCode: row['country_code']! as String,
            date: DateTime.parse(row['date_key']! as String),
            name: row['name']! as String,
            descriptionKo: row['description_ko'] as String?,
            descriptionEn: row['description_en'] as String?,
            category: row['category']! as String,
            isSubstitute: row['is_substitute'] == 1,
            source: row['source']! as String,
          ),
        )
        .toList(growable: false);
  }

  Future<void> applyRemoteHolidayChanges(
    List<Map<String, dynamic>> items,
    String cursor,
  ) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final item in items) {
        final holiday = Map<String, dynamic>.from(
          item['holiday']! as Map<dynamic, dynamic>,
        );
        await txn.insert('holidays', <String, Object?>{
          'country_code': holiday['country_code']! as String,
          'date_key': holiday['date']! as String,
          'name': holiday['name']! as String,
          'description_ko': holiday['description_ko'] as String?,
          'description_en': holiday['description_en'] as String?,
          'category': holiday['category']! as String,
          'is_substitute': holiday['is_substitute'] == true ? 1 : 0,
          'source': holiday['source']! as String,
          'is_deleted': item['is_deleted'] == true ? 1 : 0,
          'server_updated_at': item['updated_at'] as String?,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await txn.insert('sync_meta', {
        'key': 'holiday_cursor',
        'value': cursor,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<String?> _metaValue(String key) async {
    final db = await _db;
    final rows = await db.query(
      'sync_meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['value']! as String;
  }

  Future<void> applyRemoteChanges(
    List<Map<String, dynamic>> items,
    String cursor,
  ) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final item in items) {
        final todoJson = Map<String, dynamic>.from(
          item['todo']! as Map<dynamic, dynamic>,
        );
        final todo = Todo.fromJson(todoJson);
        await txn.insert('todos', <String, Object?>{
          'id': todo.id,
          'date_key': _dateKey(todo.scheduledAt),
          'payload': jsonEncode(todoJson),
          'is_deleted': item['is_deleted'] == true ? 1 : 0,
          'server_updated_at': item['updated_at'] as String?,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await txn.insert('sync_meta', {
        'key': 'schedule_cursor',
        'value': cursor,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<Todo> _findTodo(DatabaseExecutor db, int id) async {
    final rows = await db.query(
      'todos',
      columns: ['payload'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Local todo $id was not found');
    return _todoFromRow(rows.single);
  }

  Future<void> _writeTodo(
    DatabaseExecutor db,
    Todo todo, {
    required bool isDeleted,
  }) async {
    await db.insert('todos', <String, Object?>{
      'id': todo.id,
      'date_key': _dateKey(todo.scheduledAt),
      'payload': jsonEncode(_todoToJson(todo)),
      'is_deleted': isDeleted ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _queue(
    DatabaseExecutor db,
    int todoId,
    String operation,
    Map<String, dynamic> payload,
  ) async {
    final createdAt = DateTime.now().toUtc().toIso8601String();
    final existing = await db.query(
      'sync_outbox',
      columns: ['id'],
      where: 'todo_id = ? AND batch_id IS NULL',
      whereArgs: [todoId],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      await db.update(
        'sync_outbox',
        {
          'operation': operation,
          'payload': jsonEncode(payload),
          'created_at': createdAt,
        },
        where: 'id = ?',
        whereArgs: [existing.single['id']],
      );
      return;
    }
    await db.insert('sync_outbox', <String, Object?>{
      'todo_id': todoId,
      'operation_id': _uuidV4(),
      'batch_id': null,
      'operation': operation,
      'payload': jsonEncode(payload),
      'created_at': createdAt,
    });
  }

  Future<PendingTodoChange?> _pendingForTodo(
    DatabaseExecutor db,
    int todoId,
  ) async {
    final rows = await db.query(
      'sync_outbox',
      where: 'todo_id = ? AND batch_id IS NULL',
      whereArgs: [todoId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return PendingTodoChange(
      rowId: row['id']! as int,
      todoId: row['todo_id']! as int,
      operation: row['operation']! as String,
      payload: jsonDecode(row['payload']! as String) as Map<String, dynamic>,
      createdAt: DateTime.parse(row['created_at']! as String),
      batchId: row['batch_id'] as String?,
      operationId: row['operation_id']! as String,
    );
  }

  Future<void> _removePendingForTodo(DatabaseExecutor db, int todoId) =>
      db.delete(
        'sync_outbox',
        where: 'todo_id = ? AND batch_id IS NULL',
        whereArgs: [todoId],
      );

  Future<int> _nextTemporaryId(DatabaseExecutor db) async {
    final rows = await db.query(
      'sync_meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['next_local_todo_id'],
      limit: 1,
    );
    final id = rows.isEmpty ? -1 : int.parse(rows.single['value']! as String);
    await db.insert('sync_meta', {
      'key': 'next_local_todo_id',
      'value': '${id - 1}',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return id;
  }

  Todo _todoFromRow(Map<String, Object?> row) => Todo.fromJson(
    jsonDecode(row['payload']! as String) as Map<String, dynamic>,
  );

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> _todoToJson(Todo todo) => <String, dynamic>{
    'id': todo.id,
    'eta': todo.eta?.toIso8601String(),
    'scheduled_date': _dateKey(todo.scheduledAt),
    'description': todo.description,
    'is_completed': todo.isCompleted,
    'user': <String, dynamic>{
      'user_id': todo.user.userId,
      'user_name': todo.user.userName,
      'phone_number': todo.user.phoneNumber,
    },
    'alarm': <String, dynamic>{
      'alarm_id': todo.alarm.alarmId,
      'alarm_music': todo.alarm.alarmMusic,
      'alarm_text': todo.alarm.alarmText,
      'minutes_before': todo.alarm.minutesBefore,
    },
    'location': todo.location == null
        ? null
        : <String, dynamic>{
            'location_id': todo.location!.locationId,
            'name': todo.location!.name,
            'latitude': todo.location!.latitude,
            'longitude': todo.location!.longitude,
            'source_id': todo.location!.sourceId,
          },
  };

  Map<String, dynamic> _offlinePayload(Todo todo) => <String, dynamic>{
    'eta': todo.eta?.toIso8601String(),
    'scheduled_date': _dateKey(todo.scheduledAt),
    'description': todo.description,
    'alarm_minutes_before': todo.alarm.minutesBefore,
    'location_id': todo.location?.locationId,
    'is_completed': todo.isCompleted,
  };

  PendingTodoChange _pendingFromRow(Map<String, Object?> row) =>
      PendingTodoChange(
        rowId: row['id']! as int,
        todoId: row['todo_id']! as int,
        operation: row['operation']! as String,
        payload: jsonDecode(row['payload']! as String) as Map<String, dynamic>,
        createdAt: DateTime.parse(row['created_at']! as String),
        batchId: row['batch_id'] as String?,
        operationId: row['operation_id']! as String,
      );

  static String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  static Future<void> _createSyncBatchTable(Database db) async {
    await db.execute('''
      CREATE TABLE sync_batches (
        batch_id TEXT PRIMARY KEY,
        status TEXT NOT NULL,
        operation_count INTEGER NOT NULL,
        attempt_count INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        last_attempt_at TEXT
      )
    ''');
  }

  static Future<void> _upgradeSyncOutbox(Database db) async {
    await db.execute('ALTER TABLE sync_outbox RENAME TO sync_outbox_v2');
    await db.execute('''
      CREATE TABLE sync_outbox (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        todo_id INTEGER NOT NULL,
        operation_id TEXT NOT NULL UNIQUE,
        batch_id TEXT,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    final legacy = await db.query('sync_outbox_v2', orderBy: 'id ASC');
    for (final row in legacy) {
      await db.insert('sync_outbox', <String, Object?>{
        'id': row['id'],
        'todo_id': row['todo_id'],
        'operation_id': _uuidV4(),
        'batch_id': null,
        'operation': row['operation'],
        'payload': row['payload'],
        'created_at': row['created_at'],
      });
    }
    await db.execute('DROP TABLE sync_outbox_v2');
    await db.execute('''
      CREATE UNIQUE INDEX idx_sync_outbox_unbatched_todo
      ON sync_outbox(todo_id) WHERE batch_id IS NULL
    ''');
    await _createSyncBatchTable(db);
  }

  static Future<void> _createHolidayTable(Database db) async {
    await db.execute('''
      CREATE TABLE holidays (
        country_code TEXT NOT NULL,
        date_key TEXT NOT NULL,
        name TEXT NOT NULL,
        description_ko TEXT,
        description_en TEXT,
        category TEXT NOT NULL,
        is_substitute INTEGER NOT NULL DEFAULT 0,
        source TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        server_updated_at TEXT,
        PRIMARY KEY (country_code, date_key)
      )
    ''');
    await db.execute('''
      CREATE INDEX idx_holidays_country_deleted_date
      ON holidays(country_code, is_deleted, date_key)
    ''');
  }
}
