import 'package:flutter/material.dart';

import '../../models/todo.dart';

class ScheduleCard extends StatelessWidget {
  const ScheduleCard({
    super.key,
    required this.todo,
    required this.use24HourClock,
    this.onComplete,
    this.showCheckbox = true,
    this.backgroundColor = const Color(0xFFF4F2FC),
    this.showDate = false,
    this.fieldKeyPrefix,
    this.onDateTap,
    this.onTimeTap,
    this.onDescriptionTap,
    this.onAlarmTap,
    this.trailing,
  });

  final Todo todo;
  final bool use24HourClock;
  final VoidCallback? onComplete;
  final bool showCheckbox;
  final Color backgroundColor;
  final bool showDate;
  final String? fieldKeyPrefix;
  final VoidCallback? onDateTap;
  final VoidCallback? onTimeTap;
  final VoidCallback? onDescriptionTap;
  final VoidCallback? onAlarmTap;
  final Widget? trailing;

  String get _period => todo.scheduledAt.hour < 12 ? 'AM' : 'PM';

  String get _clockTime {
    final rawHour = todo.scheduledAt.hour;
    final minute = todo.scheduledAt.minute.toString().padLeft(2, '0');
    final hour = use24HourClock
        ? rawHour
        : (rawHour % 12 == 0 ? 12 : rawHour % 12);
    return '${hour.toString().padLeft(2, '0')}:$minute';
  }

  String get _dateText =>
      '${todo.scheduledAt.year}.${todo.scheduledAt.month.toString().padLeft(2, '0')}.${todo.scheduledAt.day.toString().padLeft(2, '0')}';

  Key? _fieldKey(String field) =>
      fieldKeyPrefix == null ? null : Key('$fieldKeyPrefix-$field');

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF8D7ED8);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          if (showDate) ...[
            InkWell(
              key: _fieldKey('date'),
              onTap: onDateTap,
              borderRadius: BorderRadius.circular(8),
              child: Text(
                _dateText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF17171B),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              SizedBox(
                width: 104,
                height: 58,
                child: Center(
                  child: InkWell(
                    key: _fieldKey('time'),
                    onTap: onTimeTap,
                    borderRadius: BorderRadius.circular(8),
                    child: Semantics(
                      label: use24HourClock
                          ? _clockTime
                          : '$_clockTime $_period',
                      child: ExcludeSemantics(
                        child: Text.rich(
                          TextSpan(
                            style: const TextStyle(
                              color: Color(0xFF26262C),
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                            ),
                            children: [
                              TextSpan(text: _clockTime),
                              TextSpan(
                                text: ' $_period',
                                style: TextStyle(
                                  color: use24HourClock
                                      ? Colors.transparent
                                      : const Color(0xFF26262C),
                                ),
                              ),
                            ],
                          ),
                          key: const Key('scheduleTime'),
                          maxLines: 1,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      key: _fieldKey('description'),
                      onTap: onDescriptionTap,
                      borderRadius: BorderRadius.circular(6),
                      child: Text(
                        todo.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${todo.location?.name ?? '장소 없음'} · ',
                          style: const TextStyle(
                            color: Color(0xFF84838B),
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                        InkWell(
                          key: _fieldKey('alarm'),
                          onTap: onAlarmTap,
                          borderRadius: BorderRadius.circular(6),
                          child: Text(
                            '${todo.alarm.minutesBefore}분 전 알림',
                            style: const TextStyle(
                              color: Color(0xFF84838B),
                              fontSize: 11,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (trailing != null)
                trailing!
              else if (showCheckbox)
                Checkbox(
                  key: Key('scheduleCheckbox-${todo.id}'),
                  value: todo.isCompleted,
                  onChanged: todo.isCompleted || onComplete == null
                      ? null
                      : (checked) {
                          if (checked == true) onComplete!();
                        },
                  activeColor: accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              if (!showCheckbox && trailing == null) const SizedBox(width: 40),
            ],
          ),
        ],
      ),
    );
  }
}
