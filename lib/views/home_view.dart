import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/startup_profiler.dart';
import '../models/chat_result.dart';
import '../models/todo.dart';
import '../providers/chat_provider.dart';
import '../providers/clock_format_provider.dart';
import '../providers/holiday_provider.dart';
import '../providers/repository_provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/sync_provider.dart';
import 'widgets/central_server_offline_popup.dart';
import 'widgets/chat_composer.dart';
import 'widgets/clock_format_toggle.dart';
import 'widgets/recovery_panel.dart';
import 'widgets/schedule_card.dart';
import 'widgets/schedule_change_preview.dart';
import 'widgets/schedule_edit_sheets.dart';
import 'widgets/swipe_delete_card.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView>
    with WidgetsBindingObserver {
  static const _recoveryCommand = '\uBCF5\uAD6C';

  Timer? _draftTimer;
  Timer? _recoveryHintTimer;
  String _currentDraft = '';
  String? _lastAutoSubmittedDraft;
  bool _previewDraftStale = false;
  int _chatClearRevision = 0;
  int _chatReplacementRevision = 0;
  String _chatReplacementText = '';
  bool _showRecoveryHint = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(centralSyncProvider.notifier).synchronizeOnResume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftTimer?.cancel();
    _recoveryHintTimer?.cancel();
    super.dispose();
  }

  void _onDraftChanged(String value) {
    _draftTimer?.cancel();
    _currentDraft = value;
    final trimmed = value.trim();
    final chat = ref.read(chatProvider);
    final previewMayBeOutdated = chat.preview != null || chat.isSending;
    final stale = previewMayBeOutdated && trimmed != _lastAutoSubmittedDraft;
    if (stale != _previewDraftStale && mounted) {
      setState(() => _previewDraftStale = stale);
    }
    if (trimmed.isEmpty || trimmed == _lastAutoSubmittedDraft) return;
    _draftTimer = Timer(
      AppConfig.chatInputDebounce,
      () => _autoSubmitDraft(trimmed),
    );
  }

  Future<void> _autoSubmitDraft(String expectedDraft) async {
    final current = _currentDraft.trim();
    if (current.isEmpty ||
        current != expectedDraft ||
        current == _lastAutoSubmittedDraft) {
      return;
    }
    final chat = ref.read(chatProvider);
    if (chat.isSending || chat.isPreviewSaving) {
      _draftTimer = Timer(
        AppConfig.chatInputDebounce,
        () => _autoSubmitDraft(expectedDraft),
      );
      return;
    }
    if (expectedDraft == _recoveryCommand) {
      await ref.read(chatProvider.notifier).showRecovery();
      if (!mounted) return;
      _lastAutoSubmittedDraft = expectedDraft;
      setState(() => _previewDraftStale = false);
      return;
    }
    await ref
        .read(chatProvider.notifier)
        .replacePreviewFromDraft(expectedDraft);
    if (!mounted) return;
    if (_currentDraft.trim() == expectedDraft &&
        ref.read(chatProvider).preview != null) {
      _lastAutoSubmittedDraft = expectedDraft;
      setState(() => _previewDraftStale = false);
    }
  }

  Future<void> _sendMessage(String message) async {
    _draftTimer?.cancel();
    final trimmed = message.trim();
    if (trimmed.isNotEmpty && message != 'YES') {
      _lastAutoSubmittedDraft = trimmed;
    }
    if (trimmed == _recoveryCommand) {
      await ref.read(chatProvider.notifier).showRecovery();
      if (mounted) setState(() => _previewDraftStale = false);
      return;
    }
    await ref.read(chatProvider.notifier).sendMessage(message);
    if (mounted) setState(() => _previewDraftStale = false);
  }

  void _clearChatInput() {
    _draftTimer?.cancel();
    _currentDraft = '';
    _lastAutoSubmittedDraft = null;
    if (!mounted) return;
    setState(() {
      _previewDraftStale = false;
      _chatClearRevision++;
    });
  }

  Future<void> _startBlankCreate() async {
    final chat = ref.read(chatProvider);
    if (chat.isSending || chat.isPreviewSaving) return;
    const text = '새로운 일정 생성';
    _draftTimer?.cancel();
    _currentDraft = text;
    _lastAutoSubmittedDraft = text;
    setState(() {
      _previewDraftStale = false;
      _chatReplacementText = text;
      _chatReplacementRevision++;
    });
    await ref
        .read(chatProvider.notifier)
        .startBlankCreate(ref.read(selectedDateProvider));
  }

  Future<void> _applyPreview() async {
    await ref.read(chatProvider.notifier).applyPreview();
    _clearChatInput();
  }

  void _editExistingTodo(Todo todo) {
    final chat = ref.read(chatProvider);
    if (chat.preview != null || chat.isSending || chat.isPreviewSaving) return;
    _draftTimer?.cancel();
    _currentDraft = '일정 수정';
    _lastAutoSubmittedDraft = '일정 수정';
    setState(() {
      _previewDraftStale = false;
      _chatReplacementText = '일정 수정';
      _chatReplacementRevision++;
    });
    ref.read(chatProvider.notifier).startLocalEdit(todo);
  }

  Future<void> _cancelPreview() async {
    _clearChatInput();
    await ref.read(chatProvider.notifier).cancelPreview();
  }

  void _closeRecovery() {
    _clearChatInput();
    ref.read(chatProvider.notifier).closeRecovery();
  }

  void _onScheduleDeleted() {
    _recoveryHintTimer?.cancel();
    if (mounted) setState(() => _showRecoveryHint = true);
    _recoveryHintTimer = Timer(const Duration(minutes: 5), () {
      if (mounted) setState(() => _showRecoveryHint = false);
    });
  }

  Future<void> _editPreviewDate(BuildContext context) async {
    final preview = ref.read(chatProvider).preview;
    final current = preview?.after;
    if (current == null) return;
    if (preview!.action == PreviewAction.create) {
      final selection = await showScheduleRecurrenceSheet(
        context,
        initialDate: current.scheduledAt,
      );
      if (selection == null) return;
      await ref
          .read(chatProvider.notifier)
          .setPreviewRecurrence(selection.rule, date: selection.date);
      return;
    }
    final selected = await showScheduleDateSheet(
      context,
      initialDate: current.scheduledAt,
      firstDate: DateTime(DateTime.now().year - AppConfig.calendarYearRange),
      lastDate: DateTime(DateTime.now().year + AppConfig.calendarYearRange),
    );
    if (selected == null) return;
    await ref
        .read(chatProvider.notifier)
        .revisePreview(
          scheduledDate: DateTime(selected.year, selected.month, selected.day),
          eta: current.hasTime
              ? DateTime(
                  selected.year,
                  selected.month,
                  selected.day,
                  current.scheduledAt.hour,
                  current.scheduledAt.minute,
                )
              : null,
        );
  }

  Future<void> _editPreviewTime(BuildContext context) async {
    final current = ref.read(chatProvider).preview?.after;
    if (current == null) return;
    final selected = await showScheduleTimeSheet(
      context,
      initialTime: TimeOfDay.fromDateTime(current.scheduledAt),
      use24HourClock: ref.read(clockFormatProvider),
    );
    if (selected == null) return;
    if (selected.clear) {
      await ref.read(chatProvider.notifier).revisePreview(clearTime: true);
      return;
    }
    final time = selected.time!;
    await ref
        .read(chatProvider.notifier)
        .revisePreview(
          eta: DateTime(
            current.scheduledAt.year,
            current.scheduledAt.month,
            current.scheduledAt.day,
            time.hour,
            time.minute,
          ),
        );
  }

  Future<void> _editPreviewDescription(BuildContext context) async {
    final current = ref.read(chatProvider).preview?.after;
    if (current == null) return;
    final value = await showScheduleDescriptionSheet(
      context,
      initialValue: current.description,
    );
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == current.description) {
      return;
    }
    await ref.read(chatProvider.notifier).revisePreview(description: trimmed);
  }

  Future<void> _editPreviewAlarm(BuildContext context) async {
    final current = ref.read(chatProvider).preview?.after;
    if (current == null) return;
    final value = await showScheduleAlarmSheet(
      context,
      initialMinutes: current.alarm.minutesBefore.clamp(
        0,
        AppConfig.maximumAlarmMinutes,
      ),
      maximumMinutes: AppConfig.maximumAlarmMinutes,
    );
    if (value == null || value == current.alarm.minutesBefore) return;
    await ref
        .read(chatProvider.notifier)
        .revisePreview(alarmMinutesBefore: value);
  }

  Future<void> _editPreviewLocation(BuildContext context) async {
    final current = ref.read(chatProvider).preview?.after;
    if (current == null) return;
    List<ScheduleLocation> locations;
    try {
      locations = await ref.read(todoRepositoryProvider).fetchLocations();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('장소 목록을 불러오지 못했습니다.')));
      return;
    }
    if (!context.mounted) return;
    final choice = await showScheduleLocationSheet(
      context,
      locations: locations,
      selectedLocation: current.location,
    );
    if (choice == null) return;
    if (choice.clear && current.location == null) return;
    if (choice.location?.locationId == current.location?.locationId) return;
    await ref
        .read(chatProvider.notifier)
        .revisePreview(location: choice.location, clearLocation: choice.clear);
  }

  Future<void> _editPreviewItemDate(
    BuildContext context,
    SchedulePreviewItem item,
  ) async {
    final current = item.after;
    if (current == null) return;
    if (item.action == PreviewAction.create) {
      final selection = await showScheduleRecurrenceSheet(
        context,
        initialDate: current.scheduledAt,
        initialRule: item.routine,
      );
      if (selection == null) return;
      await ref
          .read(chatProvider.notifier)
          .setPreviewRecurrence(
            selection.rule,
            date: selection.date,
            itemId: item.itemId,
          );
      return;
    }
    final selected = await showScheduleDateSheet(
      context,
      initialDate: current.scheduledAt,
      firstDate: DateTime(DateTime.now().year - AppConfig.calendarYearRange),
      lastDate: DateTime(DateTime.now().year + AppConfig.calendarYearRange),
    );
    if (selected == null) return;
    await ref
        .read(chatProvider.notifier)
        .revisePreviewItem(
          item.itemId,
          scheduledDate: DateTime(selected.year, selected.month, selected.day),
          eta: current.hasTime
              ? DateTime(
                  selected.year,
                  selected.month,
                  selected.day,
                  current.scheduledAt.hour,
                  current.scheduledAt.minute,
                )
              : null,
        );
  }

  Future<void> _editPreviewItemTime(
    BuildContext context,
    SchedulePreviewItem item,
  ) async {
    final current = item.after;
    if (current == null) return;
    final selected = await showScheduleTimeSheet(
      context,
      initialTime: TimeOfDay.fromDateTime(current.scheduledAt),
      use24HourClock: ref.read(clockFormatProvider),
    );
    if (selected == null) return;
    if (selected.clear) {
      await ref
          .read(chatProvider.notifier)
          .revisePreviewItem(item.itemId, clearTime: true);
      return;
    }
    final time = selected.time!;
    await ref
        .read(chatProvider.notifier)
        .revisePreviewItem(
          item.itemId,
          eta: DateTime(
            current.scheduledAt.year,
            current.scheduledAt.month,
            current.scheduledAt.day,
            time.hour,
            time.minute,
          ),
        );
  }

  Future<void> _editPreviewItemDescription(
    BuildContext context,
    SchedulePreviewItem item,
  ) async {
    final current = item.after;
    if (current == null) return;
    final value = await showScheduleDescriptionSheet(
      context,
      initialValue: current.description,
    );
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == current.description) {
      return;
    }
    await ref
        .read(chatProvider.notifier)
        .revisePreviewItem(item.itemId, description: trimmed);
  }

  Future<void> _editPreviewItemAlarm(
    BuildContext context,
    SchedulePreviewItem item,
  ) async {
    final current = item.after;
    if (current == null) return;
    final value = await showScheduleAlarmSheet(
      context,
      initialMinutes: current.alarm.minutesBefore.clamp(
        0,
        AppConfig.maximumAlarmMinutes,
      ),
      maximumMinutes: AppConfig.maximumAlarmMinutes,
    );
    if (value != null) {
      await ref
          .read(chatProvider.notifier)
          .revisePreviewItem(item.itemId, alarmMinutesBefore: value);
    }
  }

  Future<void> _editPreviewItemLocation(
    BuildContext context,
    SchedulePreviewItem item,
  ) async {
    final current = item.after;
    if (current == null) return;
    try {
      final locations = await ref.read(todoRepositoryProvider).fetchLocations();
      if (!context.mounted) return;
      final choice = await showScheduleLocationSheet(
        context,
        locations: locations,
        selectedLocation: current.location,
      );
      if (choice != null) {
        await ref
            .read(chatProvider.notifier)
            .revisePreviewItem(
              item.itemId,
              location: choice.location,
              clearLocation: choice.clear,
            );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('장소 목록을 불러오지 못했습니다.')));
      }
    }
  }

  Future<void> _openCalendar() async {
    final selectedDate = ref.read(selectedDateProvider);
    final date = await showScheduleDateSheet(
      context,
      initialDate: selectedDate,
      firstDate: DateTime(DateTime.now().year - AppConfig.calendarYearRange),
      lastDate: DateTime(DateTime.now().year + AppConfig.calendarYearRange),
    );
    if (date != null) ref.read(selectedDateProvider.notifier).select(date);
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);
    final use24HourClock = ref.watch(clockFormatProvider);
    final centralSync = ref.watch(centralSyncProvider);

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final margin = constraints.maxWidth >= 600 ? 28.0 : 16.0;
                return Padding(
                  padding: EdgeInsets.fromLTRB(margin, 20, margin, 12),
                  child: Column(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: _SchedulePanel(
                              onCalendarPressed: _openCalendar,
                              onScheduleDeleted: _onScheduleDeleted,
                              onAddSchedule: _startBlankCreate,
                              onEditSchedule: _editExistingTodo,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (chat.isRecoveryVisible ||
                          chat.isAnalyzing ||
                          chat.preview != null ||
                          chat.assistantMessage != null ||
                          chat.errorMessage != null) ...[
                        ConstrainedBox(
                          key: const Key('chatResponseArea'),
                          constraints: BoxConstraints(
                            maxWidth: 440,
                            maxHeight: constraints.maxHeight * 0.36,
                          ),
                          child: SingleChildScrollView(
                            clipBehavior: Clip.none,
                            padding: const EdgeInsets.only(
                              top: 6,
                              left: 2,
                              right: 2,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (chat.isRecoveryVisible)
                                  RecoveryPanel(
                                    todos: chat.recoveryTodos,
                                    use24HourClock: use24HourClock,
                                    onRestore: ref
                                        .read(chatProvider.notifier)
                                        .restoreDeletedTodo,
                                    onClose: _closeRecovery,
                                  )
                                else if (chat.preview != null)
                                  ScheduleChangePreviewCard(
                                    preview: chat.preview!,
                                    use24HourClock: use24HourClock,
                                    onCancel: _cancelPreview,
                                    onApply: _applyPreview,
                                    isApplying:
                                        chat.isSending || chat.isPreviewSaving,
                                    showApply: !_previewDraftStale,
                                    showLoadingOverlay: chat.isAnalyzing,
                                    onToggleItem: ref
                                        .read(chatProvider.notifier)
                                        .togglePreviewItem,
                                    onResolveItem: ref
                                        .read(chatProvider.notifier)
                                        .resolvePreviewItem,
                                    onApplyItem: ref
                                        .read(chatProvider.notifier)
                                        .applyPreviewItem,
                                    onRetryItem: (item) => ref
                                        .read(chatProvider.notifier)
                                        .revisePreviewItem(
                                          item.itemId,
                                          refreshTarget: true,
                                        ),
                                    onEditItemDate: (item) =>
                                        _editPreviewItemDate(context, item),
                                    onEditItemTime: (item) =>
                                        _editPreviewItemTime(context, item),
                                    onEditItemDescription: (item) =>
                                        _editPreviewItemDescription(
                                          context,
                                          item,
                                        ),
                                    onEditItemAlarm: (item) =>
                                        _editPreviewItemAlarm(context, item),
                                    onEditItemLocation: (item) =>
                                        _editPreviewItemLocation(context, item),
                                    onEditDate: chat.isPreviewSaving
                                        ? null
                                        : () => _editPreviewDate(context),
                                    onEditTime: chat.isPreviewSaving
                                        ? null
                                        : () => _editPreviewTime(context),
                                    onEditDescription: chat.isPreviewSaving
                                        ? null
                                        : () =>
                                              _editPreviewDescription(context),
                                    onEditAlarm: chat.isPreviewSaving
                                        ? null
                                        : () => _editPreviewAlarm(context),
                                    onEditLocation: chat.isPreviewSaving
                                        ? null
                                        : () => _editPreviewLocation(context),
                                  )
                                else if (chat.isAnalyzing)
                                  const _ChatLoadingPanel()
                                else if (chat.assistantMessage != null)
                                  _InfoMessage(
                                    key: const Key('assistantResponse'),
                                    message: chat.assistantMessage!,
                                  ),
                                if (chat.errorMessage != null) ...[
                                  const SizedBox(height: 8),
                                  _InfoMessage(
                                    key: const Key('chatErrorResponse'),
                                    message: chat.errorMessage!,
                                    isError: true,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: ChatComposer(
                          isSending: chat.isSending || chat.isPreviewSaving,
                          onSend: _sendMessage,
                          onChanged: _onDraftChanged,
                          clearRevision: _chatClearRevision,
                          replacementRevision: _chatReplacementRevision,
                          replacementText: _chatReplacementText,
                          hintText: _showRecoveryHint
                              ? '삭제된 일정을 복구하시려면 복구를 입력하세요'
                              : 'Skechat으로 일정을 관리해보세요!',
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (centralSync.status == CentralSyncStatus.offline)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 12,
              left: 16,
              right: 16,
              child: Align(
                alignment: Alignment.topCenter,
                child: CentralServerOfflinePopup(
                  pendingCount: centralSync.pendingCount,
                  nextAttemptAt: centralSync.nextAttemptAt,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SchedulePanel extends ConsumerStatefulWidget {
  const _SchedulePanel({
    required this.onCalendarPressed,
    required this.onScheduleDeleted,
    required this.onAddSchedule,
    required this.onEditSchedule,
  });

  final VoidCallback onCalendarPressed;
  final VoidCallback onScheduleDeleted;
  final VoidCallback onAddSchedule;
  final ValueChanged<Todo> onEditSchedule;

  @override
  ConsumerState<_SchedulePanel> createState() => _SchedulePanelState();
}

class _SchedulePanelState extends ConsumerState<_SchedulePanel>
    with SingleTickerProviderStateMixin {
  final _scheduleScrollController = ScrollController();
  final _autoScrolledDates = <String>{};
  final _revealTimers = <Timer>[];
  late final AnimationController _pageExitController;
  double _exitDirection = -1;
  bool _isChangingDate = false;
  bool _contentBlank = false;
  bool _deferredStartupScheduled = false;
  bool _backgroundServicesEnabled = false;
  String? _revealedDateKey;
  int _visibleScheduleCount = 0;

  @override
  void initState() {
    super.initState();
    _pageExitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void dispose() {
    for (final timer in _revealTimers) {
      timer.cancel();
    }
    _pageExitController.dispose();
    _scheduleScrollController.dispose();
    super.dispose();
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> _navigateTo(DateTime target) async {
    final current = ref.read(selectedDateProvider);
    final normalized = DateTime(target.year, target.month, target.day);
    if (_isChangingDate || normalized == current) return;
    _isChangingDate = true;
    _exitDirection = normalized.isAfter(current) ? -1 : 1;
    await _pageExitController.forward(from: 0);
    if (!mounted) return;
    for (final timer in _revealTimers) {
      timer.cancel();
    }
    _revealTimers.clear();
    setState(() {
      _contentBlank = true;
      _revealedDateKey = null;
      _visibleScheduleCount = 0;
    });
    ref.read(selectedDateProvider.notifier).select(normalized);
    if (_scheduleScrollController.hasClients) {
      _scheduleScrollController.jumpTo(0);
    }
    _pageExitController.value = 0;
    _isChangingDate = false;
  }

  void _revealSchedules(DateTime date, int count) {
    final key = _dateKey(date);
    if (_revealedDateKey == key) return;
    _revealedDateKey = key;
    for (final timer in _revealTimers) {
      timer.cancel();
    }
    _revealTimers.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _dateKey(ref.read(selectedDateProvider)) != key) return;
      setState(() {
        _contentBlank = false;
        _visibleScheduleCount = 0;
      });
      for (var index = 0; index < count; index++) {
        _revealTimers.add(
          Timer(Duration(milliseconds: 70 * index), () {
            if (!mounted || _dateKey(ref.read(selectedDateProvider)) != key) {
              return;
            }
            setState(() => _visibleScheduleCount = index + 1);
          }),
        );
      }
    });
  }

  Widget _transitionLayer({required Widget child, Key? key}) => ClipRect(
    key: key,
    child: AnimatedBuilder(
      animation: _pageExitController,
      child: child,
      builder: (context, child) {
        final progress = Curves.easeInCubic.transform(
          _pageExitController.value,
        );
        return Opacity(
          opacity: 1 - progress,
          child: Transform.translate(
            offset: Offset(_exitDirection * 90 * progress, 0),
            child: child,
          ),
        );
      },
    ),
  );

  void _scrollToClosestOnce(DateTime date, List<Todo> todos) {
    final timedTodos = todos.where((todo) => todo.hasTime).toList();
    if (timedTodos.isEmpty || !_autoScrolledDates.add(_dateKey(date))) return;

    final sorted = [...timedTodos]
      ..sort((left, right) => left.scheduledAt.compareTo(right.scheduledAt));
    final shiftedNow = DateTime.now().toUtc().add(AppConfig.koreaUtcOffset);
    final koreaNow = DateTime(
      shiftedNow.year,
      shiftedNow.month,
      shiftedNow.day,
      shiftedNow.hour,
      shiftedNow.minute,
      shiftedNow.second,
    );
    var target = sorted.first;
    if (date.year == koreaNow.year &&
        date.month == koreaNow.month &&
        date.day == koreaNow.day) {
      target = sorted.reduce((closest, candidate) {
        final closestDistance = closest.scheduledAt.difference(koreaNow).abs();
        final candidateDistance = candidate.scheduledAt
            .difference(koreaNow)
            .abs();
        return candidateDistance < closestDistance ? candidate : closest;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetContext = GlobalObjectKey(target.id).currentContext;
      if (targetContext == null) return;
      Scrollable.ensureVisible(
        targetContext,
        alignment: 0.3,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  bool _hasPassed(Todo todo) {
    if (!todo.hasTime) return false;
    final koreaNow = DateTime.now().toUtc().add(AppConfig.koreaUtcOffset);
    final koreaWallClock = DateTime(
      koreaNow.year,
      koreaNow.month,
      koreaNow.day,
      koreaNow.hour,
      koreaNow.minute,
      koreaNow.second,
    );
    return todo.scheduledAt.isBefore(koreaWallClock);
  }

  void _startBackgroundServicesAfterLocalFrame(
    AsyncValue<ScheduleData> schedule,
  ) {
    if (_deferredStartupScheduled || schedule is! AsyncData<ScheduleData>) {
      return;
    }
    _deferredStartupScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      StartupProfiler.mark('local_schedule_frame');
      setState(() => _backgroundServicesEnabled = true);
      unawaited(
        ref.read(centralSyncProvider.notifier).startAfterLocalScheduleFrame(),
      );
    });
  }

  Widget _deletableCard(
    WidgetRef ref,
    Todo todo, {
    required bool use24HourClock,
  }) {
    return SwipeDeleteCard(
      itemId: todo.id,
      onDelete: () async {
        await ref.read(scheduleProvider.notifier).deleteTodo(todo.id);
        widget.onScheduleDeleted();
      },
      child: ScheduleCard(
        todo: todo,
        use24HourClock: use24HourClock,
        onTap: () => widget.onEditSchedule(todo),
        onCompletionChanged: (isCompleted) => ref
            .read(scheduleProvider.notifier)
            .setTodoCompleted(todo.id, isCompleted),
        backgroundColor: _hasPassed(todo)
            ? const Color(0xFFFCECEC)
            : const Color(0xFFF4F2FC),
      ),
    );
  }

  Widget _scheduleCard(
    WidgetRef ref,
    Todo todo, {
    required bool use24HourClock,
    required bool visible,
  }) {
    return TweenAnimationBuilder<double>(
      key: GlobalObjectKey(todo.id),
      tween: Tween<double>(begin: 0, end: visible ? 1 : 0),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: value,
          child: Opacity(
            key: Key('scheduleReveal-${todo.id}'),
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, -14 * (1 - value)),
              child: child,
            ),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Opacity(
          key: todo.isCompleted ? Key('completedSchedule-${todo.id}') : null,
          opacity: todo.isCompleted ? 0.48 : 1,
          child: _deletableCard(ref, todo, use24HourClock: use24HourClock),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = ref.watch(selectedDateProvider);
    ref.listen<DateTime>(selectedDateProvider, (previous, next) {
      if (previous == null || _dateKey(previous) != _dateKey(next)) {
        _autoScrolledDates.remove(_dateKey(next));
      }
    });
    final schedule = ref.watch(scheduleProvider);
    _startBackgroundServicesAfterLocalFrame(schedule);
    final use24HourClock = ref.watch(clockFormatProvider);
    final holidayCalendar = _backgroundServicesEnabled
        ? switch (ref.watch(koreanHolidayProvider)) {
            AsyncData(:final value) => value,
            _ => KoreanHolidayCalendar.fallback(),
          }
        : KoreanHolidayCalendar.fallback();
    final scheduleData = switch (schedule) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final scheduleMatchesDate =
        scheduleData != null && _dateKey(scheduleData.date) == _dateKey(date);
    final sortedTodos = [...?(scheduleMatchesDate ? scheduleData.todos : null)]
      ..sort((left, right) => left.scheduledAt.compareTo(right.scheduledAt));
    final pendingTodos = sortedTodos
        .where((todo) => !todo.isCompleted)
        .toList();
    final completedTodos = sortedTodos
        .where((todo) => todo.isCompleted)
        .toList();
    if (scheduleMatchesDate) {
      _revealSchedules(date, sortedTodos.length);
    }
    _scrollToClosestOnce(date, sortedTodos);
    return LayoutBuilder(
      builder: (context, constraints) {
        const fixedHeaderHeight = 248.0;
        final showControls =
            pendingTodos.isNotEmpty &&
            !_contentBlank &&
            constraints.maxHeight >= 280;
        final controlsHeight = showControls ? 44.0 : 0.0;
        final cardsHeight = sortedTodos.isEmpty
            ? 0.0
            : sortedTodos.length * 64.0 +
                  (completedTodos.isEmpty ? 0 : 44.0) +
                  (scheduleData?.actionError == null ? 0 : 60.0);
        final desiredHeight = fixedHeaderHeight + controlsHeight + cardsHeight;
        final panelHeight = desiredHeight
            .clamp(0.0, constraints.maxHeight)
            .toDouble();
        return Container(
          key: const Key('schedulePanel'),
          width: double.infinity,
          height: panelHeight,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [
              BoxShadow(
                color: Color(0x160F172A),
                blurRadius: 28,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      '${date.year}년',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox.square(
                    dimension: 40,
                    child: IconButton(
                      key: const Key('calendarButton'),
                      onPressed: widget.onCalendarPressed,
                      tooltip: '달력 열기',
                      icon: const Icon(Icons.calendar_month_rounded),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: Text(
                        '${date.month}월 ${date.day}일',
                        key: const Key('dateTitle'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        key: const Key('previousDateButton'),
                        onPressed: () => _navigateTo(
                          ref
                              .read(selectedDateProvider)
                              .subtract(const Duration(days: 1)),
                        ),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        key: const Key('nextDateButton'),
                        onPressed: () => _navigateTo(
                          ref
                              .read(selectedDateProvider)
                              .add(const Duration(days: 1)),
                        ),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              _WeekDateSelector(
                selectedDate: date,
                onSelected: _navigateTo,
                isHoliday: holidayCalendar.isHoliday,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('addScheduleButton'),
                  onPressed: widget.onAddSchedule,
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.add_rounded, size: 19),
                  label: const Text('일정 추가'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF4F46A5),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 2,
                    ),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              if (showControls) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _CountBadge(
                      key: const Key('todoCount'),
                      label: '할 일 ${pendingTodos.length}개',
                    ),
                    const Spacer(),
                    ClockFormatToggle(
                      use24HourClock: use24HourClock,
                      onChanged: ref
                          .read(clockFormatProvider.notifier)
                          .setUse24HourClock,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Expanded(
                child: _transitionLayer(
                  key: const Key('scheduleTransitionLayer'),
                  child: _contentBlank
                      ? const SizedBox.expand()
                      : schedule.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : schedule.hasError
                      ? const Center(
                          child: _InfoMessage(
                            message:
                                '서버에 연결할 수 없습니다. Python API 실행 상태를 확인해 주세요.',
                            isError: true,
                          ),
                        )
                      : sortedTodos.isEmpty
                      ? const SizedBox.expand()
                      : Scrollbar(
                          key: const Key('scheduleScrollbar'),
                          controller: _scheduleScrollController,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            key: const Key('scheduleScrollView'),
                            controller: _scheduleScrollController,
                            padding: const EdgeInsets.only(right: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (scheduleData?.actionError != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _InfoMessage(
                                      message: scheduleData!.actionError!,
                                      isError: true,
                                    ),
                                  ),
                                ...pendingTodos.asMap().entries.map(
                                  (entry) => _scheduleCard(
                                    ref,
                                    entry.value,
                                    use24HourClock: use24HourClock,
                                    visible: entry.key < _visibleScheduleCount,
                                  ),
                                ),
                                if (completedTodos.isNotEmpty &&
                                    _visibleScheduleCount >
                                        pendingTodos.length) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    key: const Key('completedSectionHeader'),
                                    children: [
                                      const Expanded(child: Divider()),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        child: Text(
                                          '완료된 일 ${completedTodos.length}개',
                                          style: const TextStyle(
                                            color: Color(0xFF777780),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const Expanded(child: Divider()),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ...completedTodos.asMap().entries.map(
                                    (entry) => _scheduleCard(
                                      ref,
                                      entry.value,
                                      use24HourClock: use24HourClock,
                                      visible:
                                          pendingTodos.length + entry.key <
                                          _visibleScheduleCount,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WeekDateSelector extends StatelessWidget {
  const _WeekDateSelector({
    required this.selectedDate,
    required this.onSelected,
    required this.isHoliday,
  });

  static const _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;
  final bool Function(DateTime date) isHoliday;

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  bool _isSelected(DateTime date) =>
      date.year == selectedDate.year &&
      date.month == selectedDate.month &&
      date.day == selectedDate.day;

  @override
  Widget build(BuildContext context) {
    final monday = selectedDate.subtract(
      Duration(days: selectedDate.weekday - DateTime.monday),
    );
    return LayoutBuilder(
      key: const Key('weekDateSelector'),
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth / 7;
        final selectedIndex = selectedDate.weekday - DateTime.monday;
        return SizedBox(
          height: 46,
          child: Stack(
            children: [
              AnimatedPositioned(
                key: const Key('weekSelectionIndicator'),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: itemWidth * selectedIndex,
                top: 0,
                width: itemWidth,
                bottom: 0,
                child: Container(
                  key: const Key('selectedWeekDate'),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1AA36F),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              Row(
                children: List.generate(7, (index) {
                  final date = monday.add(Duration(days: index));
                  final selected = _isSelected(date);
                  final holiday = isHoliday(date);
                  final dayColor = holiday
                      ? const Color(0xFFC53E4A)
                      : index == 5
                      ? const Color(0xFF4777C7)
                      : index == 6
                      ? const Color(0xFFC5535D)
                      : const Color(0xFF63636B);
                  return Expanded(
                    child: Semantics(
                      selected: selected,
                      button: true,
                      label:
                          '${date.month}월 ${date.day}일 ${_weekdayLabels[index]}요일'
                          '${holiday ? ', 공휴일' : ''}',
                      child: InkWell(
                        key: Key('weekDate-${_dateKey(date)}'),
                        onTap: () => onSelected(date),
                        borderRadius: BorderRadius.circular(14),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 180),
                                style: TextStyle(
                                  color: selected ? Colors.white : dayColor,
                                  fontSize: 11,
                                  height: 1,
                                  fontWeight: selected
                                      ? FontWeight.w900
                                      : FontWeight.w700,
                                ),
                                child: Text(_weekdayLabels[index]),
                              ),
                              const SizedBox(height: 3),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 180),
                                style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : holiday
                                      ? const Color(0xFFC53E4A)
                                      : const Color(0xFF24242A),
                                  fontSize: 13,
                                  height: 1,
                                  fontWeight: selected
                                      ? FontWeight.w900
                                      : FontWeight.w700,
                                ),
                                child: Text('${date.day}'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF28282E),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoMessage extends StatelessWidget {
  const _InfoMessage({super.key, required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFF1F1) : const Color(0xFFF2F7F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: isError ? const Color(0xFFB42318) : const Color(0xFF48645A),
          height: 1.4,
        ),
      ),
    );
  }
}

class _ChatLoadingPanel extends StatelessWidget {
  const _ChatLoadingPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('chatLoadingPanel'),
      width: double.infinity,
      height: 118,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x160F172A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: const Center(
        child: CircularProgressIndicator(key: Key('chatLoadingIndicator')),
      ),
    );
  }
}
