import 'package:flutter/material.dart';

import '../../models/chat_result.dart';
import 'chat_composer.dart';
import 'schedule_card.dart';

class ScheduleChangePreviewCard extends StatelessWidget {
  const ScheduleChangePreviewCard({
    super.key,
    required this.preview,
    required this.use24HourClock,
    required this.onCancel,
    required this.onApply,
    this.isApplying = false,
    this.showApply = true,
    this.showLoadingOverlay = false,
    this.onEditDate,
    this.onEditTime,
    this.onEditDescription,
    this.onEditAlarm,
    this.onEditLocation,
    this.onToggleItem,
    this.onResolveItem,
    this.onEditItemDate,
    this.onEditItemTime,
    this.onEditItemDescription,
    this.onEditItemAlarm,
    this.onEditItemLocation,
    this.onRetryItem,
    this.onApplyItem,
  });

  static const _createColor = Color(0xFFEAF7EF);
  static const _deleteColor = Color(0xFFFCECEC);

  final ScheduleChangePreview preview;
  final bool use24HourClock;
  final VoidCallback onCancel;
  final VoidCallback onApply;
  final bool isApplying;
  final bool showApply;
  final bool showLoadingOverlay;
  final VoidCallback? onEditDate;
  final VoidCallback? onEditTime;
  final VoidCallback? onEditDescription;
  final VoidCallback? onEditAlarm;
  final VoidCallback? onEditLocation;
  final void Function(String itemId, bool selected)? onToggleItem;
  final void Function(String itemId, bool apply)? onResolveItem;
  final void Function(SchedulePreviewItem item)? onEditItemDate;
  final void Function(SchedulePreviewItem item)? onEditItemTime;
  final void Function(SchedulePreviewItem item)? onEditItemDescription;
  final void Function(SchedulePreviewItem item)? onEditItemAlarm;
  final void Function(SchedulePreviewItem item)? onEditItemLocation;
  final void Function(SchedulePreviewItem item)? onRetryItem;
  final void Function(String itemId)? onApplyItem;

  Widget _batchPreview() => Column(
    key: const Key('batchPreviewCards'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        '적용할 일정을 선택하세요',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
      const SizedBox(height: 10),
      ...preview.items.map(
        (item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                key: Key('batchPreviewCheckbox-${item.itemId}'),
                value: item.selected,
                onChanged:
                    showLoadingOverlay ||
                        item.conflicted ||
                        item.requiresConfirmation && !item.confirmed
                    ? null
                    : (value) =>
                          onToggleItem?.call(item.itemId, value ?? false),
              ),
              Expanded(
                child: Opacity(
                  opacity: item.selected ? 1 : 0.62,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _ActionBadge(
                          action: item.action,
                          entityType: item.entityType,
                        ),
                      ),
                      if (item.routine != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _routineLabel(item.routine!),
                          key: Key('routineRule-${item.itemId}'),
                          style: const TextStyle(
                            color: Color(0xFF5B4AA8),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      const SizedBox(height: 5),
                      if (item.warning != null) ...[
                        Container(
                          key: Key('batchWarning-${item.itemId}'),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7E0),
                            border: Border.all(color: const Color(0xFFF2C45E)),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    color: Color(0xFF9A6700),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      item.warning!,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (item.confirmationQuestion != null) ...[
                                const SizedBox(height: 7),
                                Text(item.confirmationQuestion!),
                                const SizedBox(height: 9),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    ChoiceChip(
                                      key: Key('warningApply-${item.itemId}'),
                                      label: const Text('적용'),
                                      selected: item.confirmed && item.selected,
                                      onSelected: (_) => onResolveItem?.call(
                                        item.itemId,
                                        true,
                                      ),
                                    ),
                                    ChoiceChip(
                                      key: Key('warningExclude-${item.itemId}'),
                                      label: const Text('제외'),
                                      selected:
                                          item.confirmed && !item.selected,
                                      onSelected: (_) => onResolveItem?.call(
                                        item.itemId,
                                        false,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 7),
                      ],
                      if (item.conflicted) ...[
                        Container(
                          key: Key('batchConflict-${item.itemId}'),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFECEA),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.sync_problem_rounded,
                                color: Color(0xFFB42318),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.conflictMessage ?? '서버의 최신 일정과 충돌했습니다.',
                                ),
                              ),
                              TextButton(
                                onPressed: () => onRetryItem?.call(item),
                                child: const Text('새로고침'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 7),
                      ],
                      ScheduleCard(
                        todo: item.after ?? item.before!,
                        use24HourClock: use24HourClock,
                        showCheckbox: false,
                        showDate: true,
                        showEmptyLocation: true,
                        showEmptyTimeLabel: true,
                        fieldKeyPrefix: 'batchPreview-${item.itemId}',
                        backgroundColor: item.action == PreviewAction.delete
                            ? _deleteColor
                            : _createColor,
                        onDateTap: item.after == null
                            ? null
                            : () => onEditItemDate?.call(item),
                        onTimeTap: item.after == null
                            ? null
                            : () => onEditItemTime?.call(item),
                        onDescriptionTap: item.after == null
                            ? null
                            : () => onEditItemDescription?.call(item),
                        onAlarmTap: item.after == null
                            ? null
                            : () => onEditItemAlarm?.call(item),
                        onLocationTap: item.after == null
                            ? null
                            : () => onEditItemLocation?.call(item),
                        trailing: AnimatedOkButton(
                          key: Key('confirmPreviewItem-${item.itemId}'),
                          onPressed:
                              item.requiresConfirmation && !item.confirmed ||
                                  item.action == PreviewAction.create &&
                                      (item.after?.description.trim().isEmpty ??
                                          true)
                              ? null
                              : () => onApplyItem?.call(item.itemId),
                          isBusy: isApplying,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      if (showApply)
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            key: const Key('applySelectedPreviewItems'),
            onPressed: preview.items.any((item) => item.selected)
                ? onApply
                : null,
            icon: isApplying
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.done_all_rounded),
            label: const Text('선택한 일정 모두 적용'),
          ),
        ),
    ],
  );

  String _routineLabel(RoutinePreviewRule rule) {
    final count = rule.repeatInterval;
    final weekdays = rule.weekdays.map(_weekdayLabel).join('·');
    return switch (rule.frequency) {
      RoutineFrequency.daily => count == 1 ? '매일' : '$count일마다',
      RoutineFrequency.weekly =>
        '${count == 1 ? '매주' : '$count주마다'}${weekdays.isEmpty ? '' : ' $weekdays'}',
      RoutineFrequency.monthly =>
        '${count == 1 ? '매월' : '$count개월마다'} ${rule.dayOfMonth ?? rule.startDate.day}일',
      RoutineFrequency.yearly => count == 1 ? '매년' : '$count년마다',
    };
  }

  String _weekdayLabel(String value) =>
      const {
        'MON': '월',
        'TUE': '화',
        'WED': '수',
        'THU': '목',
        'FRI': '금',
        'SAT': '토',
        'SUN': '일',
      }[value] ??
      value;

  Widget _editableCard({
    required Key key,
    required String fieldKeyPrefix,
    required Color backgroundColor,
  }) => ScheduleCard(
    key: key,
    todo: preview.after!,
    use24HourClock: use24HourClock,
    showCheckbox: false,
    showDate: true,
    fieldKeyPrefix: fieldKeyPrefix,
    backgroundColor: backgroundColor,
    onDateTap: onEditDate,
    onTimeTap: onEditTime,
    onDescriptionTap: onEditDescription,
    onAlarmTap: onEditAlarm,
    onLocationTap: onEditLocation,
    showEmptyLocation: true,
    showEmptyTimeLabel: true,
    trailing: showApply
        ? AnimatedOkButton(
            onPressed:
                preview.action == PreviewAction.create &&
                    preview.after!.description.trim().isEmpty
                ? null
                : onApply,
            isBusy: isApplying,
          )
        : null,
  );

  Widget _withClose(Widget child) => Stack(
    clipBehavior: Clip.none,
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 22, 14, 14),
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
        child: child,
      ),
      if (showLoadingOverlay)
        Positioned.fill(
          child: AbsorbPointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.74),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  key: Key('previewLoadingIndicator'),
                ),
              ),
            ),
          ),
        ),
      Positioned(
        top: -4,
        right: -4,
        child: IconButton(
          key: const Key('cancelPreviewButton'),
          onPressed: showLoadingOverlay ? null : onCancel,
          tooltip: '미리보기 취소',
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF5D5B64),
            side: const BorderSide(color: Color(0xFFE2E1E6)),
          ),
          icon: const Icon(Icons.close_rounded, size: 18),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (preview.items.isNotEmpty) return _withClose(_batchPreview());
    return _withClose(switch (preview.action) {
      PreviewAction.create => _editableCard(
        key: const Key('createPreviewCard'),
        fieldKeyPrefix: 'createPreview',
        backgroundColor: _createColor,
      ),
      PreviewAction.update => Column(
        key: const Key('updatePreviewCards'),
        children: [
          Opacity(
            opacity: 0.58,
            child: ScheduleCard(
              key: const Key('updateBeforeCard'),
              todo: preview.before!,
              use24HourClock: use24HourClock,
              showCheckbox: false,
              showDate: true,
              showEmptyLocation: true,
              showEmptyTimeLabel: true,
              fieldKeyPrefix: 'updateBefore',
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Icon(
              Icons.arrow_downward_rounded,
              size: 20,
              color: Color(0xFF74727B),
            ),
          ),
          _editableCard(
            key: const Key('updateAfterCard'),
            fieldKeyPrefix: 'updateAfter',
            backgroundColor: _createColor,
          ),
        ],
      ),
      PreviewAction.delete => ScheduleCard(
        key: const Key('deletePreviewCard'),
        todo: preview.before!,
        use24HourClock: use24HourClock,
        showCheckbox: false,
        showDate: true,
        showEmptyLocation: true,
        showEmptyTimeLabel: true,
        fieldKeyPrefix: 'deletePreview',
        backgroundColor: _deleteColor,
        trailing: showApply
            ? AnimatedOkButton(onPressed: onApply, isBusy: isApplying)
            : null,
      ),
      PreviewAction.mixed => const SizedBox.shrink(),
    });
  }
}

class _ActionBadge extends StatelessWidget {
  const _ActionBadge({required this.action, required this.entityType});

  final PreviewAction action;
  final PreviewEntityType entityType;

  @override
  Widget build(BuildContext context) {
    final (label, color) = entityType == PreviewEntityType.routine
        ? ('루틴', const Color(0xFF5B4AA8))
        : switch (action) {
            PreviewAction.create => ('생성', const Color(0xFF16734B)),
            PreviewAction.update => ('수정', const Color(0xFF4F46A5)),
            PreviewAction.delete => ('삭제', const Color(0xFFB42318)),
            PreviewAction.mixed => ('혼합', const Color(0xFF5D5B64)),
          };
    return Container(
      key: Key('batchAction-${action.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
