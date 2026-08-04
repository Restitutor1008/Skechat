import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../data/services/api_service.dart';
import '../models/chat_result.dart';
import '../models/todo.dart';
import '../services/local_schedule_text_parser.dart';
import 'repository_provider.dart';
import 'schedule_provider.dart';
import 'sync_provider.dart';

part 'chat_provider.freezed.dart';

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(
  ChatNotifier.new,
);

@freezed
abstract class ChatState with _$ChatState {
  const factory ChatState({
    @Default(false) bool isSending,
    @Default(false) bool isAnalyzing,
    @Default(false) bool isPreviewSaving,
    @Default(false) bool isRecoveryVisible,
    @Default(<Todo>[]) List<Todo> recoveryTodos,
    String? assistantMessage,
    String? errorMessage,
    ScheduleChangePreview? preview,
  }) = _ChatState;
}

class ChatNotifier extends Notifier<ChatState> {
  int _previewRevision = 0;
  int _pipelineRevision = 0;

  @override
  ChatState build() => const ChatState();

  Future<T> _retryAfterTimeout<T>(Future<T> Function() request) async {
    for (
      var attempt = 1;
      attempt <= AppConfig.chatTimeoutMaximumAttempts;
      attempt++
    ) {
      try {
        return await request();
      } on ApiTimeoutException {
        if (attempt == AppConfig.chatTimeoutMaximumAttempts) rethrow;
        await Future<void>.delayed(AppConfig.chatTimeoutRetryDelay * attempt);
      }
    }
    throw StateError('Unreachable timeout retry state');
  }

  void togglePreviewItem(String itemId, bool selected) {
    final current = state.preview;
    if (current == null || current.items.isEmpty || state.isSending) return;
    state = state.copyWith(
      preview: current.copyWith(
        items: current.items
            .map(
              (item) => item.itemId == itemId
                  ? (item.requiresConfirmation && !item.confirmed
                        ? item
                        : item.copyWith(selected: selected))
                  : item,
            )
            .toList(),
      ),
    );
  }

  void resolvePreviewItem(String itemId, bool apply) {
    final current = state.preview;
    if (current == null || state.isSending) return;
    state = state.copyWith(
      preview: current.copyWith(
        items: current.items
            .map(
              (item) => item.itemId == itemId
                  ? item.copyWith(confirmed: true, selected: apply)
                  : item,
            )
            .toList(),
      ),
    );
  }

  Future<void> revisePreviewItem(
    String itemId, {
    DateTime? eta,
    DateTime? scheduledDate,
    bool clearTime = false,
    String? description,
    int? alarmMinutesBefore,
    ScheduleLocation? location,
    bool clearLocation = false,
    bool refreshTarget = false,
  }) async {
    final current = state.preview;
    if (current == null || state.isPreviewSaving) return;
    final matching = current.items
        .where((item) => item.itemId == itemId)
        .toList();
    final item = matching.isEmpty ? null : matching.first;
    if (item == null || item.action == PreviewAction.delete && !refreshTarget) {
      return;
    }
    final changes = <String, dynamic>{};
    if (eta != null || clearTime) changes['eta'] = eta?.toIso8601String();
    if (scheduledDate != null) {
      changes['scheduled_date'] = scheduledDate.toIso8601String().substring(
        0,
        10,
      );
    }
    if (description != null) changes['description'] = description;
    if (alarmMinutesBefore != null) {
      changes['alarm_minutes_before'] = alarmMinutesBefore;
    }
    if (location != null || clearLocation) {
      changes['location_id'] = location?.locationId;
    }
    if (refreshTarget) changes['refresh_target'] = true;
    if (changes.isEmpty) return;

    Todo? revisedAfter = item.after;
    if (revisedAfter != null) {
      if (eta != null) revisedAfter = revisedAfter.copyWith(eta: eta);
      if (clearTime) revisedAfter = revisedAfter.copyWith(eta: null);
      if (scheduledDate != null) {
        revisedAfter = revisedAfter.copyWith(scheduledDate: scheduledDate);
      }
      if (description != null) {
        revisedAfter = revisedAfter.copyWith(description: description);
      }
      if (alarmMinutesBefore != null) {
        revisedAfter = revisedAfter.copyWith(
          alarm: revisedAfter.alarm.copyWith(minutesBefore: alarmMinutesBefore),
        );
      }
      if (location != null || clearLocation) {
        revisedAfter = revisedAfter.copyWith(location: location);
      }
    }
    final optimistic = current.copyWith(
      items: current.items
          .map(
            (candidate) => candidate.itemId == itemId
                ? candidate.copyWith(
                    after: revisedAfter,
                    selected: candidate.requiresConfirmation
                        ? false
                        : candidate.selected,
                    confirmed: candidate.requiresConfirmation
                        ? false
                        : candidate.confirmed,
                  )
                : candidate,
          )
          .toList(),
    );
    state = state.copyWith(
      preview: optimistic,
      isPreviewSaving: !current.operationId.startsWith('local:'),
    );
    if (current.operationId.startsWith('local:')) return;
    try {
      final updated = await ref
          .read(todoRepositoryProvider)
          .revisePreviewItem(current.operationId, itemId, changes);
      state = state.copyWith(preview: updated);
    } catch (_) {
      state = state.copyWith(
        preview: current,
        errorMessage: '항목 변경을 저장하지 못했습니다.',
      );
    } finally {
      state = state.copyWith(isPreviewSaving: false);
    }
  }

  Future<void> setPreviewRecurrence(
    RoutinePreviewRule? rule, {
    required DateTime date,
    String? itemId,
  }) async {
    final current = state.preview;
    if (current == null || state.isPreviewSaving) return;
    if (current.items.isEmpty) {
      final todo = current.after;
      if (todo == null || current.action != PreviewAction.create) return;
      if (rule == null) {
        await revisePreview(scheduledDate: date);
        return;
      }
      state = state.copyWith(isPreviewSaving: true, errorMessage: null);
      try {
        final updated = await ref
            .read(todoRepositoryProvider)
            .replacePreviewWithRoutine(todo, rule, _nextPipelineRevision());
        state = state.copyWith(preview: updated);
      } catch (_) {
        state = state.copyWith(errorMessage: '반복 규칙을 저장하지 못했습니다.');
      } finally {
        state = state.copyWith(isPreviewSaving: false);
      }
      return;
    }
    if (itemId == null) return;
    final matches = current.items
        .where((item) => item.itemId == itemId)
        .toList();
    if (matches.isEmpty || matches.single.after == null) return;
    final target = matches.single;
    state = state.copyWith(isPreviewSaving: true, errorMessage: null);
    try {
      final updated = await ref
          .read(todoRepositoryProvider)
          .revisePreviewItem(
            current.operationId,
            itemId,
            rule == null
                ? {
                    'clear_routine': true,
                    'scheduled_date': date.toIso8601String().substring(0, 10),
                  }
                : {'routine': rule.toJson(target.after!)},
          );
      state = state.copyWith(preview: updated);
    } catch (_) {
      state = state.copyWith(errorMessage: '반복 규칙을 저장하지 못했습니다.');
    } finally {
      state = state.copyWith(isPreviewSaving: false);
    }
  }

  Future<void> startBlankCreate(DateTime date) async {
    if (state.isSending || state.isPreviewSaving) return;
    final revision = _nextPipelineRevision();
    final operationId = 'local:create:$revision';
    state = state.copyWith(
      preview: ScheduleChangePreview(
        operationId: operationId,
        action: PreviewAction.create,
        pipelineRevision: revision,
        after: Todo(
          id: -revision,
          eta: null,
          scheduledDate: DateTime(date.year, date.month, date.day),
          description: '',
          user: const ScheduleUser(
            userId: AppConfig.defaultUserId,
            userName: AppConfig.defaultUserId,
            phoneNumber: '',
          ),
          alarm: const ScheduleAlarm(
            alarmId: 'local-preview',
            alarmMusic: null,
            alarmText: null,
            minutesBefore: 10,
          ),
          location: null,
        ),
      ),
      isSending: false,
      isAnalyzing: false,
      errorMessage: null,
      assistantMessage: null,
      recoveryTodos: const [],
      isRecoveryVisible: false,
    );
  }

  void startLocalEdit(Todo todo) {
    if (state.isSending || state.isPreviewSaving || state.preview != null) {
      return;
    }
    final revision = _nextPipelineRevision();
    state = state.copyWith(
      preview: ScheduleChangePreview(
        operationId: 'local:update:${todo.id}:$revision',
        action: PreviewAction.update,
        pipelineRevision: revision,
        before: todo,
        after: todo,
      ),
      assistantMessage: null,
      errorMessage: null,
      recoveryTodos: const [],
      isRecoveryVisible: false,
    );
  }

  Future<void> showRecovery() async {
    if (state.isSending) return;
    final previousPreview = state.preview;
    state = state.copyWith(
      isSending: true,
      errorMessage: null,
      assistantMessage: null,
    );
    try {
      if (previousPreview != null) {
        await ref
            .read(todoRepositoryProvider)
            .cancelPreview(previousPreview.operationId);
        _pipelineRevision = 0;
      }
      final todos = await ref.read(todoRepositoryProvider).fetchDeletedTodos();
      state = state.copyWith(
        isSending: false,
        preview: null,
        recoveryTodos: todos,
        isRecoveryVisible: true,
      );
    } catch (_) {
      state = state.copyWith(
        isSending: false,
        preview: previousPreview,
        errorMessage: '삭제된 일정을 불러오지 못했습니다.',
      );
    }
  }

  void closeRecovery() {
    state = state.copyWith(recoveryTodos: const [], isRecoveryVisible: false);
  }

  Future<void> restoreDeletedTodo(int id) async {
    final previous = state.recoveryTodos;
    state = state.copyWith(
      recoveryTodos: previous.where((todo) => todo.id != id).toList(),
      errorMessage: null,
    );
    try {
      await ref.read(todoRepositoryProvider).restoreTodo(id);
      await ref.read(scheduleProvider.notifier).refreshFromLocal();
      await ref.read(centralSyncProvider.notifier).noteLocalChange();
    } catch (_) {
      state = state.copyWith(
        recoveryTodos: previous,
        errorMessage: '일정을 복구하지 못했습니다.',
      );
    }
  }

  Future<void> revisePreview({
    DateTime? eta,
    DateTime? scheduledDate,
    bool clearTime = false,
    String? description,
    int? alarmMinutesBefore,
    ScheduleLocation? location,
    bool clearLocation = false,
  }) async {
    final current = state.preview;
    final currentAfter = current?.after;
    if (state.isPreviewSaving ||
        current == null ||
        currentAfter == null ||
        current.action == PreviewAction.delete) {
      return;
    }
    final changes = <String, dynamic>{};
    if (eta != null || clearTime) changes['eta'] = eta?.toIso8601String();
    if (scheduledDate != null) {
      changes['scheduled_date'] = scheduledDate.toIso8601String().substring(
        0,
        10,
      );
    }
    if (description != null) changes['description'] = description;
    if (alarmMinutesBefore != null) {
      changes['alarm_minutes_before'] = alarmMinutesBefore;
    }
    if (location != null || clearLocation) {
      changes['location_id'] = location?.locationId;
    }
    if (changes.isEmpty) return;

    final revision = ++_previewRevision;
    var revisedAfter = currentAfter;
    if (eta != null) revisedAfter = revisedAfter.copyWith(eta: eta);
    if (clearTime) revisedAfter = revisedAfter.copyWith(eta: null);
    if (scheduledDate != null) {
      revisedAfter = revisedAfter.copyWith(scheduledDate: scheduledDate);
    }
    if (description != null) {
      revisedAfter = revisedAfter.copyWith(description: description);
    }
    if (alarmMinutesBefore != null) {
      revisedAfter = revisedAfter.copyWith(
        alarm: revisedAfter.alarm.copyWith(minutesBefore: alarmMinutesBefore),
      );
    }
    if (location != null || clearLocation) {
      revisedAfter = revisedAfter.copyWith(location: location);
    }
    state = state.copyWith(
      preview: current.copyWith(after: revisedAfter),
      isPreviewSaving: !current.operationId.startsWith('local:'),
      errorMessage: null,
    );
    if (current.operationId.startsWith('local:')) return;
    try {
      await ref
          .read(todoRepositoryProvider)
          .revisePreview(current.operationId, changes);
    } catch (_) {
      if (revision == _previewRevision) {
        state = state.copyWith(
          preview: current,
          errorMessage: '미리보기 변경 내용을 저장하지 못했습니다.',
        );
      }
    } finally {
      if (revision == _previewRevision) {
        state = state.copyWith(isPreviewSaving: false);
      }
    }
  }

  Future<void> cancelPreview() async {
    final current = state.preview;
    if (current == null) return;
    _previewRevision++;
    state = state.copyWith(
      preview: null,
      isPreviewSaving: false,
      errorMessage: null,
    );
    if (current.operationId.startsWith('local:')) {
      _pipelineRevision = 0;
      return;
    }
    try {
      await ref.read(todoRepositoryProvider).cancelPreview(current.operationId);
      _pipelineRevision = 0;
      state = state.copyWith(assistantMessage: null);
    } catch (_) {
      state = state.copyWith(
        preview: current,
        errorMessage: '미리보기를 취소하지 못했습니다.',
      );
    }
  }

  Future<void> applyPreview() async {
    final current = state.preview;
    if (current == null || state.isSending) return;
    if (current.items.any(
      (item) =>
          item.selected &&
          item.action == PreviewAction.create &&
          (item.after?.description.trim().isEmpty ?? true),
    )) {
      state = state.copyWith(errorMessage: '생성할 일정 또는 루틴의 내용을 입력해 주세요.');
      return;
    }
    if (!current.operationId.startsWith('local:')) {
      await sendMessage('YES');
      return;
    }
    if (current.items.any(
      (item) => item.requiresConfirmation && !item.confirmed,
    )) {
      state = state.copyWith(errorMessage: '경고가 있는 항목의 확인 질문에 답해 주세요.');
      return;
    }
    if (current.operationId.startsWith('local:') && current.items.isNotEmpty) {
      if (!current.items.any((item) => item.selected)) return;
      state = state.copyWith(isSending: true, errorMessage: null);
      try {
        await ref.read(todoRepositoryProvider).applyLocalMixedPreview(current);
        state = state.copyWith(
          preview: null,
          assistantMessage: '오프라인 일정 변경을 기기에 저장했습니다.',
        );
        _pipelineRevision = 0;
        await ref.read(scheduleProvider.notifier).refreshFromLocal();
        await ref.read(centralSyncProvider.notifier).noteLocalChange();
      } catch (_) {
        state = state.copyWith(errorMessage: '여러 일정 변경을 로컬에 저장하지 못했습니다.');
      } finally {
        state = state.copyWith(isSending: false);
      }
      return;
    }
    final after = current.after;
    if (after == null) return;
    if (after.description.trim().isEmpty) {
      state = state.copyWith(errorMessage: '일정 내용을 입력해 주세요.');
      return;
    }
    state = state.copyWith(isSending: true, errorMessage: null);
    try {
      final repository = ref.read(todoRepositoryProvider);
      if (current.action == PreviewAction.create) {
        await repository.createLocalTodo(after);
      } else if (current.action == PreviewAction.update) {
        await repository.updateLocalTodo(after);
      }
      state = state.copyWith(preview: null);
      _pipelineRevision = 0;
      await ref.read(scheduleProvider.notifier).refreshFromLocal();
      await ref.read(centralSyncProvider.notifier).noteLocalChange();
    } catch (_) {
      state = state.copyWith(errorMessage: '일정을 로컬에 저장하지 못했습니다.');
    } finally {
      state = state.copyWith(isSending: false);
    }
  }

  Future<void> applyPreviewItem(String itemId) async {
    final current = state.preview;
    if (current == null || state.isSending) return;
    final matches = current.items
        .where((item) => item.itemId == itemId)
        .toList();
    if (matches.isEmpty) return;
    final item = matches.single;
    if (item.requiresConfirmation && !item.confirmed) {
      state = state.copyWith(errorMessage: '이 항목의 확인 질문에 먼저 답해 주세요.');
      return;
    }
    if (item.action == PreviewAction.create &&
        (item.after?.description.trim().isEmpty ?? true)) {
      state = state.copyWith(errorMessage: '일정 내용을 입력해 주세요.');
      return;
    }
    state = state.copyWith(isSending: true, errorMessage: null);
    try {
      final isRoutine = item.entityType == PreviewEntityType.routine;
      if (isRoutine) {
        await ref.read(todoRepositoryProvider).createRoutineFromPreview(item);
      } else {
        await ref.read(todoRepositoryProvider).applyLocalPreviewItem(item);
      }
      final remaining = current.items
          .where((candidate) => candidate.itemId != itemId)
          .toList();
      if (remaining.isEmpty && !current.operationId.startsWith('local:')) {
        await ref
            .read(todoRepositoryProvider)
            .cancelPreview(current.operationId);
      }
      state = state.copyWith(
        preview: remaining.isEmpty ? null : current.copyWith(items: remaining),
        assistantMessage: remaining.isEmpty
            ? '일정을 기기에 저장했습니다.'
            : '일정 한 건을 저장했습니다. 남은 항목을 계속 확인해 주세요.',
      );
      if (isRoutine) {
        await ref
            .read(centralSyncProvider.notifier)
            .synchronizeAfterServerMutation();
      } else {
        await ref.read(scheduleProvider.notifier).refreshFromLocal();
        await ref.read(centralSyncProvider.notifier).noteLocalChange();
      }
      if (remaining.isEmpty) _pipelineRevision = 0;
    } catch (_) {
      state = state.copyWith(errorMessage: '일정을 개별 저장하지 못했습니다.');
    } finally {
      state = state.copyWith(isSending: false);
    }
  }

  Future<void> sendMessage(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty || state.isSending) return;
    final previousPreview = state.preview;
    final isConfirmation = trimmed.toUpperCase() == 'YES';
    final requestRevision = isConfirmation
        ? (previousPreview?.pipelineRevision ?? _nextPipelineRevision())
        : _nextPipelineRevision();
    state = state.copyWith(
      isSending: true,
      isAnalyzing: trimmed.toUpperCase() != 'YES',
      errorMessage: null,
      assistantMessage: null,
      recoveryTodos: const [],
      isRecoveryVisible: false,
    );
    _previewRevision++;
    try {
      if (trimmed.toUpperCase() == 'YES' &&
          previousPreview != null &&
          previousPreview.items.isNotEmpty) {
        await ref
            .read(todoRepositoryProvider)
            .selectPreviewItems(
              previousPreview.operationId,
              previousPreview.items
                  .where((item) => item.selected)
                  .map((item) => item.itemId)
                  .toList(),
              previousPreview.items
                  .where((item) => item.confirmed)
                  .map((item) => item.itemId)
                  .toList(),
            );
      }
      final contextDate = ref.read(selectedDateProvider);
      final result = await _retryAfterTimeout(
        () => ref
            .read(todoRepositoryProvider)
            .sendMessage(
              trimmed,
              contextDate,
              pipelineRevision: requestRevision,
              pipelineOperationId: isConfirmation
                  ? previousPreview?.operationId
                  : null,
            ),
      );
      if (result.preview != null) {
        _pipelineRevision = result.preview!.pipelineRevision;
      } else if (isConfirmation) {
        _pipelineRevision = 0;
      }
      state = state.copyWith(
        assistantMessage: result.preview == null && result.errorCode != null
            ? result.message
            : null,
        preview: result.preview,
      );
      if (trimmed.toUpperCase() == 'YES' && result.preview == null) {
        await ref
            .read(centralSyncProvider.notifier)
            .synchronizeAfterServerMutation();
      }
    } catch (error) {
      if (!isConfirmation) {
        final schedules = await ref
            .read(todoRepositoryProvider)
            .fetchTodos(ref.read(selectedDateProvider));
        final offline = LocalScheduleTextParser().parse(
          message: trimmed,
          contextDate: ref.read(selectedDateProvider),
          schedules: schedules,
          pipelineRevision: requestRevision,
        );
        if (offline != null) {
          state = state.copyWith(
            preview: offline,
            assistantMessage: '서버에 연결되지 않아 기기에서 일정을 분석했습니다.',
            errorMessage: null,
          );
          return;
        }
      }
      state = state.copyWith(
        preview: previousPreview,
        errorMessage: switch (error) {
          ApiTimeoutException() => '서버 응답 시간이 초과되었습니다. 잠시 후 다시 입력해 주세요.',
          ApiException(:final message) => message,
          _ => '서버와 통신하지 못했습니다. Python API와 LLM 실행 상태를 확인해 주세요.',
        },
      );
    } finally {
      state = state.copyWith(isSending: false, isAnalyzing: false);
    }
  }

  int _nextPipelineRevision() {
    final now = DateTime.now().microsecondsSinceEpoch;
    _pipelineRevision = now > _pipelineRevision ? now : _pipelineRevision + 1;
    return _pipelineRevision;
  }

  Future<void> replacePreviewFromDraft(String message) => sendMessage(message);
}
