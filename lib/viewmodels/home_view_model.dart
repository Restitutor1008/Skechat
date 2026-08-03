import 'package:flutter/foundation.dart';

import '../data/repositories/todo_repository.dart';
import '../models/chat_result.dart';
import '../models/todo.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel(this._repository, {DateTime? initialDate})
    : selectedDate = initialDate ?? DateTime.now();

  final TodoRepository _repository;
  DateTime selectedDate;
  List<Todo> todos = const [];
  List<Todo> recoveryTodos = const [];
  bool use24HourClock = true;
  bool isLoading = false;
  bool isSending = false;
  bool isPreviewSaving = false;
  bool isRecoveryVisible = false;
  String? errorMessage;
  String? assistantMessage;
  ScheduleChangePreview? changePreview;
  int _previewRevision = 0;

  Future<void> loadTodos() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      todos = await _repository.fetchTodos(selectedDate);
    } catch (_) {
      errorMessage = '서버에 연결할 수 없습니다. Python API 실행 상태를 확인해 주세요.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectDate(DateTime date) async {
    _previewRevision++;
    isPreviewSaving = false;
    changePreview = null;
    selectedDate = DateTime(date.year, date.month, date.day);
    await loadTodos();
  }

  Future<void> moveDate(int days) =>
      selectDate(selectedDate.add(Duration(days: days)));

  void setClockFormat(bool value) {
    use24HourClock = value;
    notifyListeners();
  }

  Future<void> completeTodo(int id) async {
    final index = todos.indexWhere((todo) => todo.id == id);
    if (index < 0 || todos[index].isCompleted) return;

    final previous = todos[index];
    todos = [
      for (final todo in todos)
        if (todo.id == id) todo.copyWith(isCompleted: true) else todo,
    ];
    errorMessage = null;
    notifyListeners();

    try {
      final saved = await _repository.completeTodo(id);
      todos = [
        for (final todo in todos)
          if (todo.id == id) saved else todo,
      ];
    } catch (_) {
      todos = [
        for (final todo in todos)
          if (todo.id == id) previous else todo,
      ];
      errorMessage = '일정을 완료 처리하지 못했습니다.';
    }
    notifyListeners();
  }

  Future<void> deleteTodoDirect(int id) async {
    final previous = todos;
    todos = todos.where((todo) => todo.id != id).toList();
    errorMessage = null;
    notifyListeners();
    try {
      await _repository.deleteTodo(id);
    } catch (_) {
      todos = previous;
      errorMessage = '일정을 삭제하지 못했습니다.';
      notifyListeners();
    }
  }

  Future<void> showRecovery() async {
    if (isSending) return;
    isSending = true;
    errorMessage = null;
    final previousPreview = changePreview;
    notifyListeners();
    try {
      if (previousPreview != null) await _repository.cancelPreview();
      changePreview = null;
      assistantMessage = null;
      recoveryTodos = await _repository.fetchDeletedTodos();
      isRecoveryVisible = true;
    } catch (_) {
      changePreview = previousPreview;
      errorMessage = '삭제된 일정을 불러오지 못했습니다.';
    } finally {
      isSending = false;
      notifyListeners();
    }
  }

  void closeRecovery() {
    recoveryTodos = const [];
    isRecoveryVisible = false;
    notifyListeners();
  }

  Future<void> restoreDeletedTodo(int id) async {
    final previous = recoveryTodos;
    recoveryTodos = recoveryTodos.where((todo) => todo.id != id).toList();
    notifyListeners();
    try {
      await _repository.restoreTodo(id);
      await loadTodos();
    } catch (_) {
      recoveryTodos = previous;
      errorMessage = '일정을 복구하지 못했습니다.';
      notifyListeners();
    }
  }

  Future<void> revisePreview({
    DateTime? eta,
    String? description,
    int? alarmMinutesBefore,
  }) async {
    final current = changePreview;
    final currentAfter = current?.after;
    if (isPreviewSaving ||
        current == null ||
        currentAfter == null ||
        current.action == PreviewAction.delete) {
      return;
    }
    final changes = <String, dynamic>{};
    if (eta != null) changes['eta'] = eta.toIso8601String();
    if (description != null) changes['description'] = description;
    if (alarmMinutesBefore != null) {
      changes['alarm_minutes_before'] = alarmMinutesBefore;
    }
    if (changes.isEmpty) return;

    final revision = ++_previewRevision;
    final revisedAfter = currentAfter.copyWith(
      eta: eta,
      description: description,
      alarm: alarmMinutesBefore == null
          ? null
          : currentAfter.alarm.copyWith(minutesBefore: alarmMinutesBefore),
    );
    changePreview = current.copyWith(after: revisedAfter);
    isPreviewSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _repository.revisePreview(current.operationId, changes);
    } catch (_) {
      if (revision == _previewRevision) {
        changePreview = current;
        errorMessage = '미리보기 변경 내용을 저장하지 못했습니다.';
        notifyListeners();
      }
    } finally {
      if (revision == _previewRevision) {
        isPreviewSaving = false;
        notifyListeners();
      }
    }
  }

  Future<void> cancelPreview() async {
    final current = changePreview;
    if (current == null) return;
    _previewRevision++;
    isPreviewSaving = false;
    changePreview = null;
    notifyListeners();
    try {
      await _repository.cancelPreview();
      assistantMessage = null;
    } catch (_) {
      changePreview = current;
      errorMessage = '미리보기를 취소하지 못했습니다.';
    }
    notifyListeners();
  }

  Future<void> sendMessage(
    String message, {
    bool cancelPendingPreview = false,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty || isSending) return;
    final previousPreview = changePreview;
    isSending = true;
    errorMessage = null;
    _previewRevision++;
    isPreviewSaving = false;
    changePreview = null;
    recoveryTodos = const [];
    isRecoveryVisible = false;
    notifyListeners();
    try {
      if (cancelPendingPreview && previousPreview != null) {
        await _repository.cancelPreview();
      }
      final result = await _repository.sendMessage(trimmed);
      assistantMessage = result.preview == null && result.errorCode != null
          ? result.message
          : null;
      changePreview = result.preview;
      await loadTodos();
    } catch (_) {
      if (cancelPendingPreview && previousPreview != null) {
        changePreview = previousPreview;
      }
      errorMessage = 'LLM 응답을 가져오지 못했습니다.';
    } finally {
      isSending = false;
      notifyListeners();
    }
  }

  Future<void> replacePreviewFromDraft(String message) =>
      sendMessage(message, cancelPendingPreview: true);
}
