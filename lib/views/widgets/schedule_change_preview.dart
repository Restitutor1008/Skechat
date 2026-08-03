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
    this.onEditDate,
    this.onEditTime,
    this.onEditDescription,
    this.onEditAlarm,
  });

  static const _createColor = Color(0xFFEAF7EF);
  static const _deleteColor = Color(0xFFFCECEC);

  final ScheduleChangePreview preview;
  final bool use24HourClock;
  final VoidCallback onCancel;
  final VoidCallback onApply;
  final bool isApplying;
  final bool showApply;
  final VoidCallback? onEditDate;
  final VoidCallback? onEditTime;
  final VoidCallback? onEditDescription;
  final VoidCallback? onEditAlarm;

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
    trailing: showApply
        ? AnimatedOkButton(onPressed: onApply, isBusy: isApplying)
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
      Positioned(
        top: -4,
        right: -4,
        child: IconButton(
          key: const Key('cancelPreviewButton'),
          onPressed: onCancel,
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
        fieldKeyPrefix: 'deletePreview',
        backgroundColor: _deleteColor,
        trailing: showApply
            ? AnimatedOkButton(onPressed: onApply, isBusy: isApplying)
            : null,
      ),
    });
  }
}
