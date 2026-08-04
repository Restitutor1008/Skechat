import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/todo.dart';

class ScheduleCard extends StatelessWidget {
  const ScheduleCard({
    super.key,
    required this.todo,
    required this.use24HourClock,
    this.onCompletionChanged,
    this.showCheckbox = true,
    this.backgroundColor = const Color(0xFFF4F2FC),
    this.showDate = false,
    this.fieldKeyPrefix,
    this.onDateTap,
    this.onTimeTap,
    this.onDescriptionTap,
    this.onAlarmTap,
    this.onLocationTap,
    this.onTap,
    this.showEmptyLocation = false,
    this.showEmptyTimeLabel = false,
    this.trailing,
  });

  final Todo todo;
  final bool use24HourClock;
  final ValueChanged<bool>? onCompletionChanged;
  final bool showCheckbox;
  final Color backgroundColor;
  final bool showDate;
  final String? fieldKeyPrefix;
  final VoidCallback? onDateTap;
  final VoidCallback? onTimeTap;
  final VoidCallback? onDescriptionTap;
  final VoidCallback? onAlarmTap;
  final VoidCallback? onLocationTap;
  final VoidCallback? onTap;
  final bool showEmptyLocation;
  final bool showEmptyTimeLabel;
  final Widget? trailing;

  String get _period =>
      todo.hasTime ? DateFormat('a', 'en_US').format(todo.scheduledAt) : '';

  String get _clockTime {
    if (!todo.hasTime) return '';
    return DateFormat(
      use24HourClock ? 'HH:mm' : 'hh:mm',
    ).format(todo.scheduledAt);
  }

  String get _dateText => DateFormat('yyyy.MM.dd').format(todo.scheduledAt);

  Key? _fieldKey(String field) =>
      fieldKeyPrefix == null ? null : Key('$fieldKeyPrefix-$field');

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF8D7ED8);
    final descriptionIsEmpty = todo.description.trim().isEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showDate) ...[
          Center(
            child: InkWell(
              key: _fieldKey('date'),
              onTap: onDateTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  _dateText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF17171B),
                    fontSize: 15,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
        ],
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              key:
                  _fieldKey('cardSurface') ??
                  Key('scheduleCardSurface-${todo.id}'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 78,
                    height: 40,
                    child: Center(
                      child: InkWell(
                        key: _fieldKey('time'),
                        onTap: onTimeTap,
                        borderRadius: BorderRadius.circular(8),
                        child: Semantics(
                          label: todo.hasTime
                              ? (use24HourClock
                                    ? _clockTime
                                    : '$_clockTime $_period')
                              : (showEmptyTimeLabel ? '시간 미입력' : '시간 없음'),
                          child: ExcludeSemantics(
                            child: Text.rich(
                              TextSpan(
                                style: const TextStyle(
                                  color: Color(0xFF26262C),
                                  fontSize: 17,
                                  height: 1,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                                children: [
                                  TextSpan(
                                    text: todo.hasTime
                                        ? _clockTime
                                        : (showEmptyTimeLabel ? '시간 미입력' : ''),
                                    style: TextStyle(
                                      color: todo.hasTime
                                          ? const Color(0xFF26262C)
                                          : const Color(0xFF8B8A92),
                                      fontSize: todo.hasTime ? 17 : 11,
                                      fontWeight: todo.hasTime
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(
                                    text: todo.hasTime ? ' $_period' : '',
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          key: _fieldKey('description'),
                          onTap: onDescriptionTap,
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: double.infinity,
                            child: Text(
                              descriptionIsEmpty ? '일정 내용을 입력하세요' : todo.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: descriptionIsEmpty
                                    ? const Color(0xFF777680)
                                    : const Color(0xFF17171B),
                                fontSize: descriptionIsEmpty ? 12 : 14,
                                height: 1.1,
                                fontWeight: descriptionIsEmpty
                                    ? FontWeight.w600
                                    : FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (todo.location != null || showEmptyLocation)
                              InkWell(
                                key: _fieldKey('location'),
                                onTap: onLocationTap,
                                borderRadius: BorderRadius.circular(6),
                                child: Text(
                                  '${todo.location?.name ?? '장소 없음'} · ',
                                  style: const TextStyle(
                                    color: Color(0xFF84838B),
                                    fontSize: 10,
                                    height: 1.15,
                                  ),
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
                                  fontSize: 10,
                                  height: 1.15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (trailing != null)
                    trailing!
                  else if (showCheckbox)
                    Checkbox(
                      key: Key('scheduleCheckbox-${todo.id}'),
                      value: todo.isCompleted,
                      onChanged: onCompletionChanged == null
                          ? null
                          : (checked) {
                              if (checked != null) {
                                onCompletionChanged!(checked);
                              }
                            },
                      activeColor: accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  if (!showCheckbox && trailing == null)
                    const SizedBox(width: 32),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
