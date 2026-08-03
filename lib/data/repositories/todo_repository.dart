import '../../models/chat_result.dart';
import '../../models/todo.dart';
import '../services/api_service.dart';

class TodoRepository {
  TodoRepository(this._api);

  final ApiService _api;

  Future<List<Todo>> fetchTodos(DateTime date) async {
    final day =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final json = await _api.getList('/api/todos?date=$day');
    return json
        .map((item) => Todo.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Todo> completeTodo(int id) async {
    final json = await _api.patch('/api/todos/$id', {'is_completed': true});
    return Todo.fromJson(json);
  }

  Future<void> deleteTodo(int id) => _api.delete('/api/todos/$id');

  Future<List<Todo>> fetchDeletedTodos() async {
    final json = await _api.getList('/api/todos/deleted');
    return json
        .map((item) => Todo.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Todo> restoreTodo(int id) async {
    final json = await _api.post('/api/todos/$id/restore', const {});
    return Todo.fromJson(json);
  }

  Future<void> revisePreview(
    String operationId,
    Map<String, dynamic> changes,
  ) async {
    await _api.patch('/api/schedule-operations/$operationId', changes);
  }

  Future<void> cancelPreview() async {
    final conversation = Uri.encodeQueryComponent(_api.conversationId);
    await _api.post(
      '/api/schedule-operations/cancel?conversation_id=$conversation&source=ui',
      const {},
    );
  }

  Future<ChatResult> sendMessage(String message) async {
    final json = await _api.post('/api/chat', {
      'message': message,
      'conversation_id': _api.conversationId,
    });
    return ChatResult.fromJson(json);
  }
}
