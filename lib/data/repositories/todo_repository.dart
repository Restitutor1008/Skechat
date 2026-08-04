import 'package:intl/intl.dart';

import '../../core/config/app_config.dart';
import '../../models/chat_result.dart';
import '../../models/holiday.dart';
import '../../models/todo.dart';
import '../local/local_todo_database.dart';
import '../services/api_service.dart';

class TodoSyncResult {
  const TodoSyncResult({
    required this.changed,
    required this.pendingCount,
    this.holidaysChanged = false,
  });

  final bool changed;
  final int pendingCount;
  final bool holidaysChanged;
}

class TodoRepository {
  TodoRepository(this._api, {LocalTodoDatabase? localDatabase})
    : _local = localDatabase;

  final ApiService _api;
  final LocalTodoDatabase? _local;

  static final _apiDateFormat = DateFormat('yyyy-MM-dd');

  Future<List<Todo>> fetchTodos(DateTime date) async {
    final local = _local;
    if (local != null) return local.todosForDate(date);
    final day = _apiDateFormat.format(date);
    final json = await _api.getList('/api/todos?date=$day');
    return json
        .map((item) => Todo.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Todo> setTodoCompleted(int id, bool isCompleted) async {
    final local = _local;
    if (local != null) return local.setCompleted(id, isCompleted);
    final json = await _api.patch('/api/todos/$id', {
      'is_completed': isCompleted,
    });
    return Todo.fromJson(json);
  }

  Future<Todo> createLocalTodo(Todo draft) async {
    final local = _local;
    if (local == null) throw StateError('Local database is unavailable');
    return local.createTodo(
      draft.copyWith(
        user: ScheduleUser(
          userId: _api.userId,
          userName: _api.userId,
          phoneNumber: '',
        ),
      ),
    );
  }

  Future<Todo> updateLocalTodo(Todo todo) async {
    final local = _local;
    if (local == null) throw StateError('Local database is unavailable');
    return local.updateTodo(todo);
  }

  Future<void> applyLocalMixedPreview(ScheduleChangePreview preview) async {
    final local = _local;
    if (local == null) throw StateError('Local database is unavailable');
    final mutations = <LocalTodoMutation>[];
    for (final item in preview.items.where((item) => item.selected)) {
      switch (item.action) {
        case PreviewAction.create:
          mutations.add(
            LocalTodoMutation(
              action: 'create',
              todo: item.after!.copyWith(
                user: ScheduleUser(
                  userId: _api.userId,
                  userName: _api.userId,
                  phoneNumber: '',
                ),
              ),
            ),
          );
          break;
        case PreviewAction.update:
          mutations.add(LocalTodoMutation(action: 'update', todo: item.after));
          break;
        case PreviewAction.delete:
          mutations.add(
            LocalTodoMutation(action: 'delete', todoId: item.before!.id),
          );
          break;
        case PreviewAction.mixed:
          throw StateError('Nested mixed preview item is unsupported');
      }
    }
    await local.applyMutations(mutations);
  }

  Future<void> applyLocalPreviewItem(SchedulePreviewItem item) async {
    await applyLocalMixedPreview(
      ScheduleChangePreview(
        operationId: 'local:item:${item.itemId}',
        action: PreviewAction.mixed,
        items: [item.copyWith(selected: true)],
      ),
    );
  }

  Future<void> deleteTodo(int id) async {
    final local = _local;
    if (local != null) {
      await local.deleteTodo(id);
      return;
    }
    await _api.delete('/api/todos/$id');
  }

  Future<List<Todo>> fetchDeletedTodos() async {
    final local = _local;
    if (local != null) return local.deletedTodos();
    final json = await _api.getList('/api/todos/deleted');
    return json
        .map((item) => Todo.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Todo> restoreTodo(int id) async {
    final local = _local;
    if (local != null) return local.restoreTodo(id);
    final json = await _api.post('/api/todos/$id/restore', const {});
    return Todo.fromJson(json);
  }

  Future<void> revisePreview(
    String operationId,
    Map<String, dynamic> changes,
  ) async {
    await _api.patch('/api/schedule-operations/$operationId', changes);
  }

  Future<void> selectPreviewItems(
    String operationId,
    List<String> selectedItemIds, [
    List<String> confirmedItemIds = const <String>[],
  ]) async {
    await _api.patch('/api/schedule-operations/$operationId/selection', {
      'selected_item_ids': selectedItemIds,
      'confirmed_item_ids': confirmedItemIds,
    });
  }

  Future<ScheduleChangePreview> revisePreviewItem(
    String operationId,
    String itemId,
    Map<String, dynamic> changes,
  ) async {
    final json = await _api.patch(
      '/api/schedule-operations/$operationId/items/$itemId',
      changes,
    );
    return ScheduleChangePreview.fromJson(json);
  }

  Future<ScheduleChangePreview> replacePreviewWithRoutine(
    Todo todo,
    RoutinePreviewRule rule,
    int pipelineRevision,
  ) async {
    final json = await _api.post('/api/schedule-operations/preview', {
      'action': 'mixed',
      'conversation_id': _api.conversationId,
      'pipeline_revision': pipelineRevision,
      'select_all': true,
      'items': [
        {
          'item_id': 'routine-1',
          'entity_type': 'routine',
          'action': 'create',
          'changes': {
            'eta': todo.eta?.toIso8601String(),
            'scheduled_date': todo.scheduledAt.toIso8601String().substring(
              0,
              10,
            ),
            if (todo.description.isNotEmpty) 'description': todo.description,
            'alarm_minutes_before': todo.alarm.minutesBefore,
          },
          'routine': rule.toJson(todo),
        },
      ],
    });
    return ScheduleChangePreview.fromJson(json);
  }

  Future<void> createRoutineFromPreview(SchedulePreviewItem item) async {
    final routine = item.routine;
    final todo = item.after;
    if (routine == null || todo == null) {
      throw StateError('Routine preview is incomplete');
    }
    await _api.post('/api/routines', routine.toJson(todo));
  }

  Future<ScheduleChangePreview> startBlankCreatePreview(
    DateTime date,
    int pipelineRevision,
  ) async {
    final midnight = DateTime(date.year, date.month, date.day);
    final json = await _api.post('/api/schedule-operations/preview', {
      'action': 'create',
      'conversation_id': _api.conversationId,
      'pipeline_revision': pipelineRevision,
      'allow_empty_description': true,
      'changes': {
        'eta': midnight.toIso8601String(),
        'location_id': null,
        'alarm_minutes_before': 10,
      },
    });
    return ScheduleChangePreview.fromJson(json);
  }

  Future<List<ScheduleLocation>> fetchLocations() async {
    final json = await _api.getList('/api/locations');
    return json
        .map(
          (item) =>
              ScheduleLocation.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<void> cancelPreview(String operationId) async {
    final conversation = Uri.encodeQueryComponent(_api.conversationId);
    final expected = Uri.encodeQueryComponent(operationId);
    await _api.post(
      '/api/schedule-operations/cancel?conversation_id=$conversation&source=ui&expected_operation_id=$expected',
      const {},
    );
  }

  Future<ChatResult> sendMessage(
    String message,
    DateTime contextDate, {
    required int pipelineRevision,
    String? pipelineOperationId,
  }) async {
    final day = _apiDateFormat.format(contextDate);
    final json = await _api.post('/api/chat', {
      'message': message,
      'conversation_id': _api.conversationId,
      'context_date': day,
      'pipeline_revision': pipelineRevision,
      'pipeline_operation_id': ?pipelineOperationId,
    }, timeout: _api.chatTimeout);
    return ChatResult.fromJson(json);
  }

  Future<int> pendingChangeCount() async => await _local?.pendingCount() ?? 0;

  Future<DateTime?> latestPendingChangeAt() =>
      _local?.latestPendingChangeAt() ?? Future<DateTime?>.value();

  Future<List<AppHoliday>> fetchHolidays() async =>
      await _local?.holidays() ?? const <AppHoliday>[];

  Future<TodoSyncResult> synchronize({bool uploadPending = true}) async {
    final local = _local;
    if (local == null) {
      return const TodoSyncResult(changed: false, pendingCount: 0);
    }

    final pendingBeforePull = await local.pendingChanges();
    final cursor = await local.syncCursor();
    final query = cursor == null
        ? ''
        : '?updated_after=${Uri.encodeQueryComponent(cursor)}';
    final response = await _api.get('/api/sync$query');
    final remoteItems = (response['items']! as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map<dynamic, dynamic>))
        .toList(growable: false);

    final localWins = <int>{};
    for (final change in pendingBeforePull) {
      Map<String, dynamic>? matchingRemote;
      for (final item in remoteItems) {
        final todo = item['todo']! as Map<dynamic, dynamic>;
        if (todo['id'] == change.todoId) {
          matchingRemote = item;
          break;
        }
      }
      if (matchingRemote == null) continue;
      if (change.batchId != null) {
        localWins.add(change.todoId);
        continue;
      }
      final remoteUpdatedAt = DateTime.parse(
        matchingRemote['updated_at']! as String,
      );
      if (remoteUpdatedAt.isAfter(change.createdAt)) {
        await local.removePendingChange(change.rowId);
      } else {
        localWins.add(change.todoId);
      }
    }

    final applicableRemoteItems = remoteItems
        .where((item) {
          final todo = item['todo']! as Map<dynamic, dynamic>;
          return !localWins.contains(todo['id']);
        })
        .toList(growable: false);
    await local.applyRemoteChanges(
      applicableRemoteItems,
      response['server_time']! as String,
    );

    final holidayCursor = await local.holidaySyncCursor();
    final holidayQuery = holidayCursor == null
        ? '?country_code=KR'
        : '?country_code=KR&updated_after=${Uri.encodeQueryComponent(holidayCursor)}';
    final holidayResponse = await _api.get('/api/holidays/sync$holidayQuery');
    final remoteHolidayItems = (holidayResponse['items']! as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map<dynamic, dynamic>))
        .toList(growable: false);
    await local.applyRemoteHolidayChanges(
      remoteHolidayItems,
      holidayResponse['server_time']! as String,
    );

    final uploadBatch = uploadPending
        ? await local.prepareUploadBatch(AppConfig.maximumCrudBatchSize)
        : null;
    if (uploadBatch != null && uploadBatch.changes.isNotEmpty) {
      await local.recordBatchAttempt(uploadBatch.batchId);
      final batchResponse = await _api.post('/api/offline/todos/batch', {
        'batch_id': uploadBatch.batchId,
        'operations': [
          for (final change in uploadBatch.changes)
            {
              'operation_id': change.operationId,
              'client_id': change.rowId,
              'operation': change.operation,
              'todo_id': change.todoId,
              'payload': change.payload,
            },
        ],
      });
      final results = (batchResponse['results']! as List<dynamic>)
          .map(
            (item) => Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
          )
          .toList(growable: false);
      if (batchResponse['batch_id'] != uploadBatch.batchId ||
          batchResponse['status'] != 'COMMITTED') {
        throw const ApiException('서버가 배치 확정 영수증을 반환하지 않았습니다.');
      }
      await local.applyCommittedBatch(uploadBatch, results);
    }
    return TodoSyncResult(
      changed:
          remoteItems.isNotEmpty ||
          remoteHolidayItems.isNotEmpty ||
          uploadBatch != null && uploadBatch.changes.isNotEmpty,
      pendingCount: await local.pendingCount(),
      holidaysChanged: remoteHolidayItems.isNotEmpty,
    );
  }
}
