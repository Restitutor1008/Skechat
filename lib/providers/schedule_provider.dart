import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/startup_profiler.dart';
import '../models/todo.dart';
import 'repository_provider.dart';
import 'sync_provider.dart';

part 'schedule_provider.freezed.dart';

final selectedDateProvider = NotifierProvider<SelectedDateNotifier, DateTime>(
  SelectedDateNotifier.new,
);

final scheduleProvider = AsyncNotifierProvider<ScheduleNotifier, ScheduleData>(
  ScheduleNotifier.new,
);

class SelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void select(DateTime value) {
    state = DateTime(value.year, value.month, value.day);
  }

  void move(int days) => select(state.add(Duration(days: days)));
}

@freezed
abstract class ScheduleData with _$ScheduleData {
  const factory ScheduleData({
    required DateTime date,
    required List<Todo> todos,
    String? actionError,
  }) = _ScheduleData;
}

class ScheduleNotifier extends AsyncNotifier<ScheduleData> {
  @override
  Future<ScheduleData> build() async {
    final date = ref.watch(selectedDateProvider);
    final repository = ref.watch(todoRepositoryProvider);
    StartupProfiler.mark('local_schedule_query_start', {'date': '$date'});
    final todos = await repository.fetchTodos(date);
    StartupProfiler.mark('local_schedule_query_end', {
      'date': '$date',
      'count': todos.length,
    });
    return ScheduleData(date: date, todos: todos);
  }

  ScheduleData? get _data => switch (state) {
    AsyncData(:final value) => value,
    _ => null,
  };

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final date = ref.read(selectedDateProvider);
      final todos = await ref.read(todoRepositoryProvider).fetchTodos(date);
      return ScheduleData(date: date, todos: todos);
    });
  }

  Future<void> refreshFromLocal() async {
    final current = _data;
    final date = ref.read(selectedDateProvider);
    final todos = await ref.read(todoRepositoryProvider).fetchTodos(date);
    state = AsyncData(
      ScheduleData(date: date, todos: todos, actionError: current?.actionError),
    );
  }

  Future<void> setTodoCompleted(int id, bool isCompleted) async {
    final current = _data;
    if (current == null) return;
    final index = current.todos.indexWhere((todo) => todo.id == id);
    if (index < 0 || current.todos[index].isCompleted == isCompleted) return;
    final previous = current.todos;
    state = AsyncData(
      ScheduleData(
        date: current.date,
        todos: [
          for (final todo in previous)
            if (todo.id == id)
              todo.copyWith(isCompleted: isCompleted)
            else
              todo,
        ],
      ),
    );
    try {
      final saved = await ref
          .read(todoRepositoryProvider)
          .setTodoCompleted(id, isCompleted);
      state = AsyncData(
        ScheduleData(
          date: current.date,
          todos: [
            for (final todo in previous)
              if (todo.id == id) saved else todo,
          ],
        ),
      );
      await ref.read(centralSyncProvider.notifier).noteLocalChange();
    } catch (_) {
      state = AsyncData(
        ScheduleData(
          date: current.date,
          todos: previous,
          actionError: '일정의 완료 상태를 변경하지 못했습니다.',
        ),
      );
    }
  }

  Future<void> deleteTodo(int id) async {
    final current = _data;
    if (current == null) return;
    final previous = current.todos;
    state = AsyncData(
      ScheduleData(
        date: current.date,
        todos: previous.where((todo) => todo.id != id).toList(),
      ),
    );
    try {
      await ref.read(todoRepositoryProvider).deleteTodo(id);
      await ref.read(centralSyncProvider.notifier).noteLocalChange();
    } catch (_) {
      state = AsyncData(
        ScheduleData(
          date: current.date,
          todos: previous,
          actionError: '일정을 삭제하지 못했습니다.',
        ),
      );
    }
  }
}
