import 'dart:async';

import 'package:flutter/material.dart';

import '../models/todo.dart';
import '../viewmodels/home_view_model.dart';
import 'widgets/chat_composer.dart';
import 'widgets/clock_format_toggle.dart';
import 'widgets/recovery_panel.dart';
import 'widgets/schedule_card.dart';
import 'widgets/schedule_change_preview.dart';
import 'widgets/swipe_delete_card.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final _scrollController = ScrollController();
  Timer? _draftTimer;
  String _currentDraft = '';
  String? _lastAutoSubmittedDraft;
  bool _previewDraftStale = false;
  int _chatClearRevision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.viewModel.loadTodos(),
    );
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _scrollController.dispose();
    widget.viewModel.dispose();
    super.dispose();
  }

  void _onDraftChanged(String value) {
    _draftTimer?.cancel();
    _currentDraft = value;
    final trimmed = value.trim();
    final previewExists = widget.viewModel.changePreview != null;
    final stale = previewExists && trimmed != _lastAutoSubmittedDraft;
    if (stale != _previewDraftStale && mounted) {
      setState(() => _previewDraftStale = stale);
    }
    if (trimmed.isEmpty || trimmed == _lastAutoSubmittedDraft) return;
    _draftTimer = Timer(
      const Duration(milliseconds: 500),
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
    final vm = widget.viewModel;
    if (vm.isSending || vm.isPreviewSaving) {
      _draftTimer = Timer(
        const Duration(milliseconds: 500),
        () => _autoSubmitDraft(expectedDraft),
      );
      return;
    }
    if (expectedDraft == '복구') {
      await vm.showRecovery();
      if (!mounted) return;
      _lastAutoSubmittedDraft = expectedDraft;
      setState(() => _previewDraftStale = false);
      return;
    }
    await vm.replacePreviewFromDraft(expectedDraft);
    if (!mounted) return;
    if (_currentDraft.trim() == expectedDraft && vm.changePreview != null) {
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
    if (trimmed == '복구') {
      await widget.viewModel.showRecovery();
      if (mounted) setState(() => _previewDraftStale = false);
      return;
    }
    final replacePending =
        message != 'YES' && widget.viewModel.changePreview != null;
    await widget.viewModel.sendMessage(
      message,
      cancelPendingPreview: replacePending,
    );
    if (mounted) setState(() => _previewDraftStale = false);
    if (!mounted || !_scrollController.hasClients) return;
    await _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
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

  Future<void> _applyPreview() async {
    await _sendMessage('YES');
    _clearChatInput();
  }

  Future<void> _cancelPreview() async {
    _clearChatInput();
    await widget.viewModel.cancelPreview();
  }

  void _closeRecovery() {
    _clearChatInput();
    widget.viewModel.closeRecovery();
  }

  Future<void> _editPreviewDate(BuildContext context) async {
    final current = widget.viewModel.changePreview?.after;
    if (current == null) return;
    final selected = await showDatePicker(
      context: context,
      initialDate: current.scheduledAt,
      firstDate: DateTime(DateTime.now().year - 10),
      lastDate: DateTime(DateTime.now().year + 10),
      helpText: '날짜 선택',
      cancelText: '취소',
      confirmText: '확인',
    );
    if (selected == null) return;
    await widget.viewModel.revisePreview(
      eta: DateTime(
        selected.year,
        selected.month,
        selected.day,
        current.scheduledAt.hour,
        current.scheduledAt.minute,
      ),
    );
  }

  Future<void> _editPreviewTime(BuildContext context) async {
    final current = widget.viewModel.changePreview?.after;
    if (current == null) return;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current.scheduledAt),
      helpText: '시각 선택',
      cancelText: '취소',
      confirmText: '확인',
    );
    if (selected == null) return;
    await widget.viewModel.revisePreview(
      eta: DateTime(
        current.scheduledAt.year,
        current.scheduledAt.month,
        current.scheduledAt.day,
        selected.hour,
        selected.minute,
      ),
    );
  }

  Future<void> _editPreviewDescription(BuildContext context) async {
    final current = widget.viewModel.changePreview?.after;
    if (current == null) return;
    var draft = current.description;
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('일정 내용 수정'),
        content: TextFormField(
          key: const Key('previewDescriptionInput'),
          initialValue: current.description,
          autofocus: true,
          maxLength: 200,
          decoration: const InputDecoration(hintText: '일정 내용을 입력하세요'),
          onChanged: (text) => draft = text,
          onFieldSubmitted: (text) => Navigator.pop(dialogContext, text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, draft),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == current.description) {
      return;
    }
    await widget.viewModel.revisePreview(description: trimmed);
  }

  Future<void> _editPreviewAlarm(BuildContext context) async {
    final current = widget.viewModel.changePreview?.after;
    if (current == null) return;
    final value = await showDialog<int>(
      context: context,
      builder: (_) => _AlarmMinutePickerDialog(
        initialMinutes: current.alarm.minutesBefore.clamp(0, 30),
      ),
    );
    if (value == null || value == current.alarm.minutesBefore) return;
    await widget.viewModel.revisePreview(alarmMinutesBefore: value);
  }

  Future<void> _openCalendar() async {
    final vm = widget.viewModel;
    final date = await showDatePicker(
      context: context,
      initialDate: vm.selectedDate,
      firstDate: DateTime(DateTime.now().year - 10),
      lastDate: DateTime(DateTime.now().year + 10),
      helpText: '날짜 선택',
      cancelText: '취소',
      confirmText: '확인',
    );
    if (date != null) await vm.selectDate(date);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;
        return Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final margin = constraints.maxWidth >= 600 ? 28.0 : 16.0;
                return Padding(
                  padding: EdgeInsets.fromLTRB(margin, 20, margin, 12),
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 440),
                              child: _SchedulePanel(
                                viewModel: vm,
                                onCalendarPressed: _openCalendar,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (vm.isRecoveryVisible ||
                          vm.changePreview != null ||
                          vm.assistantMessage != null) ...[
                        ConstrainedBox(
                          key: const Key('chatResponseArea'),
                          constraints: BoxConstraints(
                            maxWidth: 440,
                            maxHeight: constraints.maxHeight * 0.46,
                          ),
                          child: SingleChildScrollView(
                            clipBehavior: Clip.none,
                            padding: const EdgeInsets.only(
                              top: 6,
                              left: 2,
                              right: 2,
                            ),
                            child: vm.isRecoveryVisible
                                ? RecoveryPanel(
                                    todos: vm.recoveryTodos,
                                    use24HourClock: vm.use24HourClock,
                                    onRestore: vm.restoreDeletedTodo,
                                    onClose: _closeRecovery,
                                  )
                                : vm.changePreview != null
                                ? ScheduleChangePreviewCard(
                                    preview: vm.changePreview!,
                                    use24HourClock: vm.use24HourClock,
                                    onCancel: _cancelPreview,
                                    onApply: _applyPreview,
                                    isApplying: vm.isSending,
                                    showApply: !_previewDraftStale,
                                    onEditDate: vm.isPreviewSaving
                                        ? null
                                        : () => _editPreviewDate(context),
                                    onEditTime: vm.isPreviewSaving
                                        ? null
                                        : () => _editPreviewTime(context),
                                    onEditDescription: vm.isPreviewSaving
                                        ? null
                                        : () =>
                                              _editPreviewDescription(context),
                                    onEditAlarm: vm.isPreviewSaving
                                        ? null
                                        : () => _editPreviewAlarm(context),
                                  )
                                : _InfoMessage(
                                    key: const Key('assistantResponse'),
                                    message: vm.assistantMessage!,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: ChatComposer(
                          isSending: vm.isSending || vm.isPreviewSaving,
                          onSend: _sendMessage,
                          onChanged: _onDraftChanged,
                          clearRevision: _chatClearRevision,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _SchedulePanel extends StatelessWidget {
  const _SchedulePanel({
    required this.viewModel,
    required this.onCalendarPressed,
  });

  final HomeViewModel viewModel;
  final VoidCallback onCalendarPressed;

  bool _hasPassed(Todo todo) {
    final koreaNow = DateTime.now().toUtc().add(const Duration(hours: 9));
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

  Widget _deletableCard(Todo todo, {VoidCallback? onComplete}) {
    return SwipeDeleteCard(
      itemId: todo.id,
      onDelete: () => viewModel.deleteTodoDirect(todo.id),
      child: ScheduleCard(
        todo: todo,
        use24HourClock: viewModel.use24HourClock,
        onComplete: onComplete,
        backgroundColor: _hasPassed(todo)
            ? const Color(0xFFFCECEC)
            : const Color(0xFFF4F2FC),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = viewModel.selectedDate;
    final completedTodos = viewModel.todos
        .where((todo) => todo.isCompleted)
        .toList();
    final pendingTodos = viewModel.todos
        .where((todo) => !todo.isCompleted)
        .toList();
    return Container(
      key: const Key('schedulePanel'),
      width: double.infinity,
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
                dimension: 48,
                child: IconButton(
                  key: const Key('calendarButton'),
                  onPressed: onCalendarPressed,
                  tooltip: '달력 열기',
                  icon: const Icon(Icons.calendar_month_rounded),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 48,
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
                    onPressed: () => viewModel.moveDate(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    key: const Key('nextDateButton'),
                    onPressed: () => viewModel.moveDate(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          if (!viewModel.isLoading &&
              viewModel.errorMessage == null &&
              completedTodos.isNotEmpty) ...[
            ...completedTodos.map(
              (todo) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Opacity(
                  key: Key('completedSchedule-${todo.id}'),
                  opacity: 0.48,
                  child: _deletableCard(todo),
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _CountBadge(
                key: const Key('todoCount'),
                label: '할 일 ${pendingTodos.length}개',
              ),
              const Spacer(),
              ClockFormatToggle(
                use24HourClock: viewModel.use24HourClock,
                onChanged: viewModel.setClockFormat,
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (viewModel.isLoading)
            const Padding(
              padding: EdgeInsets.all(28),
              child: CircularProgressIndicator(),
            )
          else if (viewModel.errorMessage != null)
            _InfoMessage(message: viewModel.errorMessage!, isError: true)
          else if (pendingTodos.isEmpty)
            const _InfoMessage(message: '남은 할 일이 없습니다.')
          else
            ...pendingTodos.map(
              (todo) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _deletableCard(
                  todo,
                  onComplete: () => viewModel.completeTodo(todo.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AlarmMinutePickerDialog extends StatefulWidget {
  const _AlarmMinutePickerDialog({required this.initialMinutes});

  final int initialMinutes;

  @override
  State<_AlarmMinutePickerDialog> createState() =>
      _AlarmMinutePickerDialogState();
}

class _AlarmMinutePickerDialogState extends State<_AlarmMinutePickerDialog> {
  late final FixedExtentScrollController _controller;
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialMinutes;
    _controller = FixedExtentScrollController(initialItem: _selected);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('알림 시각'),
      content: SizedBox(
        width: 180,
        height: 170,
        child: ListWheelScrollView.useDelegate(
          key: const Key('alarmMinutePicker'),
          controller: _controller,
          itemExtent: 42,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: (index) => _selected = index,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: 31,
            builder: (context, index) => Center(
              child: Text('$index분 전', style: const TextStyle(fontSize: 18)),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('확인'),
        ),
      ],
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
