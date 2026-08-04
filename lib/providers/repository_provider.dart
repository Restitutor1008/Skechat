import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/todo_repository.dart';
import '../data/local/local_todo_database.dart';
import '../data/services/api_service.dart';

final localTodoDatabaseProvider = Provider<LocalTodoDatabase>((ref) {
  final database = LocalTodoDatabase();
  ref.onDispose(database.close);
  return database;
});

final todoRepositoryProvider = Provider<TodoRepository>(
  (ref) => TodoRepository(
    ApiService(),
    localDatabase: ref.watch(localTodoDatabaseProvider),
  ),
);
