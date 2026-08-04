import 'dart:math' as math;

import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';

import '../../models/todo.dart';
import '../../models/chat_result.dart';

const _accent = Color(0xFF1AA36F);
const _ink = Color(0xFF202126);
const _muted = Color(0xFF74747D);

typedef LocationSelection = ({bool clear, ScheduleLocation? location});
typedef ScheduleTimeSelection = ({bool clear, TimeOfDay? time});

class RecurrenceSelection {
  const RecurrenceSelection({required this.date, this.rule});

  final DateTime date;
  final RoutinePreviewRule? rule;
}

Future<T?> _showSkeChatSheet<T>(
  BuildContext context,
  Widget child, {
  required double heightFactor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x660F172A),
    builder: (sheetContext) {
      final media = MediaQuery.of(sheetContext);
      final keyboardInset = media.viewInsets.bottom;
      final availableHeight =
          media.size.height - keyboardInset - media.padding.top;
      final sheetHeight = math.min(
        media.size.height * heightFactor,
        availableHeight,
      );
      return AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: math.min(media.size.width, 520),
            height: sheetHeight,
            child: Material(
              key: const Key('scheduleEditorSheet'),
              color: Colors.white,
              clipBehavior: Clip.antiAlias,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

Future<DateTime?> showScheduleDateSheet(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) => _showSkeChatSheet<DateTime>(
  context,
  _DateSheet(
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
  ),
  heightFactor: 0.62,
);

Future<ScheduleTimeSelection?> showScheduleTimeSheet(
  BuildContext context, {
  required TimeOfDay initialTime,
  required bool use24HourClock,
}) => _showSkeChatSheet<ScheduleTimeSelection>(
  context,
  _TimeSheet(initialTime: initialTime, use24HourClock: use24HourClock),
  heightFactor: 0.52,
);

Future<String?> showScheduleDescriptionSheet(
  BuildContext context, {
  required String initialValue,
}) => _showSkeChatSheet<String>(
  context,
  _DescriptionSheet(initialValue: initialValue),
  heightFactor: 0.42,
);

Future<int?> showScheduleAlarmSheet(
  BuildContext context, {
  required int initialMinutes,
  required int maximumMinutes,
}) => _showSkeChatSheet<int>(
  context,
  _AlarmSheet(initialMinutes: initialMinutes, maximumMinutes: maximumMinutes),
  heightFactor: 0.45,
);

Future<LocationSelection?> showScheduleLocationSheet(
  BuildContext context, {
  required List<ScheduleLocation> locations,
  required ScheduleLocation? selectedLocation,
}) => _showSkeChatSheet<LocationSelection>(
  context,
  _LocationSheet(locations: locations, selectedLocation: selectedLocation),
  heightFactor: 0.58,
);

Future<RecurrenceSelection?> showScheduleRecurrenceSheet(
  BuildContext context, {
  required DateTime initialDate,
  RoutinePreviewRule? initialRule,
}) => _showSkeChatSheet<RecurrenceSelection>(
  context,
  _RecurrenceSheet(initialDate: initialDate, initialRule: initialRule),
  heightFactor: 0.78,
);

class _RecurrenceSheet extends StatefulWidget {
  const _RecurrenceSheet({required this.initialDate, this.initialRule});

  final DateTime initialDate;
  final RoutinePreviewRule? initialRule;

  @override
  State<_RecurrenceSheet> createState() => _RecurrenceSheetState();
}

class _RecurrenceSheetState extends State<_RecurrenceSheet> {
  late DateTime _date;
  late String _mode;
  late int _interval;
  late Set<String> _weekdays;

  static const _weekdayLabels = <String, String>{
    'MON': '월',
    'TUE': '화',
    'WED': '수',
    'THU': '목',
    'FRI': '금',
    'SAT': '토',
    'SUN': '일',
  };

  @override
  void initState() {
    super.initState();
    _date = widget.initialRule?.startDate ?? widget.initialDate;
    _mode = widget.initialRule?.frequency.name ?? 'once';
    _interval = widget.initialRule?.repeatInterval ?? 1;
    _weekdays = {...?widget.initialRule?.weekdays};
    if (_mode == 'weekly' && _weekdays.isEmpty) {
      _weekdays.add(_weekdayLabels.keys.elementAt(_date.weekday - 1));
    }
  }

  RoutinePreviewRule? get _rule {
    if (_mode == 'once') return null;
    final frequency = RoutineFrequency.values.byName(_mode);
    return RoutinePreviewRule(
      frequency: frequency,
      repeatInterval: _interval,
      weekdays: frequency == RoutineFrequency.weekly
          ? _weekdays.toList()
          : const [],
      dayOfMonth: frequency == RoutineFrequency.monthly ? _date.day : null,
      startDate: _date,
    );
  }

  @override
  Widget build(BuildContext context) => _SheetFrame(
    icon: Icons.repeat_rounded,
    title: '날짜와 반복',
    subtitle: '한 번만 실행하거나 반복 규칙을 선택하세요',
    confirmEnabled: _mode != 'weekly' || _weekdays.isNotEmpty,
    onConfirm: () =>
        Navigator.pop(context, RecurrenceSelection(date: _date, rule: _rule)),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: const Key('recurrenceMode'),
          initialValue: _mode,
          decoration: const InputDecoration(
            labelText: '반복 방식',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'once', child: Text('한 번만')),
            DropdownMenuItem(value: 'daily', child: Text('매일')),
            DropdownMenuItem(value: 'weekly', child: Text('매주 · 요일 선택')),
            DropdownMenuItem(value: 'monthly', child: Text('매월')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _mode = value;
              if (_mode == 'weekly' && _weekdays.isEmpty) {
                _weekdays.add(_weekdayLabels.keys.elementAt(_date.weekday - 1));
              }
            });
          },
        ),
        if (_mode != 'once') ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '반복 간격',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: _interval > 1
                    ? () => setState(() => _interval--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '$_interval${_mode == 'daily'
                    ? '일'
                    : _mode == 'weekly'
                    ? '주'
                    : '개월'}마다',
              ),
              IconButton(
                onPressed: () => setState(() => _interval++),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ],
        if (_mode == 'weekly') ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: _weekdayLabels.entries.map((entry) {
              final selected = _weekdays.contains(entry.key);
              return FilterChip(
                key: Key('weekday-${entry.key}'),
                label: Text(entry.value),
                selected: selected,
                onSelected: (value) => setState(() {
                  value
                      ? _weekdays.add(entry.key)
                      : _weekdays.remove(entry.key);
                }),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 12),
        CalendarDatePicker(
          initialDate: _date,
          firstDate: DateTime(DateTime.now().year - 2),
          lastDate: DateTime(DateTime.now().year + 10),
          onDateChanged: (value) => setState(() => _date = value),
        ),
      ],
    ),
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.onConfirm,
    this.confirmEnabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget body;
  final VoidCallback onConfirm;
  final bool confirmEnabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD9D9DE),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFE7F6EF),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: _accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Flexible(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: body,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('scheduleEditorCancel'),
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF5E5D65),
                    side: const BorderSide(color: Color(0xFFE0DFE4)),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '취소',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  key: const Key('scheduleEditorConfirm'),
                  onPressed: confirmEnabled ? onConfirm : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    '변경 완료',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateSheet extends StatefulWidget {
  const _DateSheet({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_DateSheet> createState() => _DateSheetState();
}

class _DateSheetState extends State<_DateSheet> {
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = DateUtils.dateOnly(widget.initialDate);
  }

  String get _selectionText =>
      '${_selected.year}년 ${_selected.month}월 ${_selected.day}일 · '
      '${const ['월', '화', '수', '목', '금', '토', '일'][_selected.weekday - 1]}요일';

  void _select(DateTime date) {
    final value = DateUtils.dateOnly(date);
    if (value.isBefore(widget.firstDate) || value.isAfter(widget.lastDate)) {
      return;
    }
    setState(() => _selected = value);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    return _SheetFrame(
      icon: Icons.calendar_month_rounded,
      title: '날짜 선택',
      subtitle: _selectionText,
      onConfirm: () => Navigator.pop(context, _selected),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('timeQuickClear'),
              onPressed: () =>
                  Navigator.pop(context, (clear: true, time: null)),
              icon: const Icon(Icons.event_available_rounded),
              label: const Text('시간 없이 오늘 안에'),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _QuickChip(
                  key: const Key('dateQuickToday'),
                  label: '오늘',
                  selected: DateUtils.isSameDay(_selected, today),
                  onTap: () => _select(today),
                ),
                _QuickChip(
                  label: '내일',
                  selected: DateUtils.isSameDay(
                    _selected,
                    today.add(const Duration(days: 1)),
                  ),
                  onTap: () => _select(today.add(const Duration(days: 1))),
                ),
                _QuickChip(
                  label: '다음 주',
                  selected: DateUtils.isSameDay(
                    _selected,
                    today.add(const Duration(days: 7)),
                  ),
                  onTap: () => _select(today.add(const Duration(days: 7))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            key: const Key('friendlyDatePicker'),
            height: 310,
            child: CalendarDatePicker2(
              config: CalendarDatePicker2Config(
                firstDate: widget.firstDate,
                lastDate: widget.lastDate,
                currentDate: today,
                firstDayOfWeek: 1,
                weekdayLabels: const ['일', '월', '화', '수', '목', '금', '토'],
                controlsHeight: 44,
                controlsTextStyle: const TextStyle(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
                weekdayLabelTextStyle: const TextStyle(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
                selectedDayHighlightColor: _accent,
                selectedDayTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
                todayTextStyle: const TextStyle(
                  color: _accent,
                  fontWeight: FontWeight.w900,
                ),
                dayBorderRadius: BorderRadius.circular(12),
                yearBorderRadius: BorderRadius.circular(12),
                monthBorderRadius: BorderRadius.circular(12),
                lastMonthIcon: const Icon(Icons.chevron_left_rounded),
                nextMonthIcon: const Icon(Icons.chevron_right_rounded),
                daySplashColor: const Color(0x3320B783),
                dynamicCalendarRows: true,
              ),
              value: [_selected],
              onValueChanged: (dates) {
                if (dates.isNotEmpty) _select(dates.first);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeSheet extends StatefulWidget {
  const _TimeSheet({required this.initialTime, required this.use24HourClock});

  final TimeOfDay initialTime;
  final bool use24HourClock;

  @override
  State<_TimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends State<_TimeSheet> {
  late int _hour;
  late int _minute;
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
    _hourController = FixedExtentScrollController(
      initialItem: widget.use24HourClock ? _hour : _displayHour - 1,
    );
    _minuteController = FixedExtentScrollController(initialItem: _minute);
  }

  int get _displayHour => ((_hour + 11) % 12) + 1;
  bool get _isPm => _hour >= 12;
  String get _timeText => widget.use24HourClock
      ? '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}'
      : '${_isPm ? '오후' : '오전'} '
            '${_displayHour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _setTime(int hour, int minute) {
    setState(() {
      _hour = hour;
      _minute = minute;
    });
    _hourController.animateToItem(
      widget.use24HourClock ? hour : ((_hour + 11) % 12),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
    _minuteController.animateToItem(
      minute,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _setPeriod(bool pm) {
    setState(() {
      if (pm && _hour < 12) _hour += 12;
      if (!pm && _hour >= 12) _hour -= 12;
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = TimeOfDay.now();
    return _SheetFrame(
      icon: Icons.schedule_rounded,
      title: '시각 선택',
      subtitle: '선택한 시각 · $_timeText',
      onConfirm: () => Navigator.pop(context, (
        clear: false,
        time: TimeOfDay(hour: _hour, minute: _minute),
      )),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _QuickChip(
                  key: const Key('timeQuickNow'),
                  label: '지금',
                  onTap: () => _setTime(now.hour, now.minute),
                ),
                _QuickChip(label: '오전 9시', onTap: () => _setTime(9, 0)),
                _QuickChip(label: '점심 12시', onTap: () => _setTime(12, 0)),
                _QuickChip(label: '오후 6시', onTap: () => _setTime(18, 0)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 164,
            decoration: BoxDecoration(
              color: const Color(0xFFF6F7F8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!widget.use24HourClock)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _PeriodButton(
                          label: '오전',
                          selected: !_isPm,
                          onTap: () => _setPeriod(false),
                        ),
                        const SizedBox(height: 8),
                        _PeriodButton(
                          label: '오후',
                          selected: _isPm,
                          onTap: () => _setPeriod(true),
                        ),
                      ],
                    ),
                  ),
                _PickerWheel(
                  key: const Key('timeHourWheel'),
                  controller: _hourController,
                  itemCount: widget.use24HourClock ? 24 : 12,
                  labelBuilder: (index) => widget.use24HourClock
                      ? index.toString().padLeft(2, '0')
                      : (index + 1).toString().padLeft(2, '0'),
                  onSelected: (index) => setState(() {
                    if (widget.use24HourClock) {
                      _hour = index;
                    } else {
                      final displayHour = index + 1;
                      _hour = (displayHour % 12) + (_isPm ? 12 : 0);
                    }
                  }),
                ),
                const Text(
                  ':',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                _PickerWheel(
                  key: const Key('timeMinuteWheel'),
                  controller: _minuteController,
                  itemCount: 60,
                  labelBuilder: (index) => index.toString().padLeft(2, '0'),
                  onSelected: (index) => setState(() => _minute = index),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerWheel extends StatelessWidget {
  const _PickerWheel({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.labelBuilder,
    required this.onSelected,
  });

  final FixedExtentScrollController controller;
  final int itemCount;
  final String Function(int index) labelBuilder;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 150,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 42,
        diameterRatio: 1.35,
        perspective: 0.004,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onSelected,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: itemCount,
          builder: (context, index) => Center(
            child: Text(
              labelBuilder(index),
              style: const TextStyle(
                color: _ink,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DescriptionSheet extends StatefulWidget {
  const _DescriptionSheet({required this.initialValue});

  final String initialValue;

  @override
  State<_DescriptionSheet> createState() => _DescriptionSheetState();
}

class _DescriptionSheetState extends State<_DescriptionSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.text.trim();
    return _SheetFrame(
      icon: Icons.edit_note_rounded,
      title: '일정 내용',
      subtitle: '무엇을 할 예정인지 알아보기 쉽게 적어 주세요.',
      confirmEnabled: value.isNotEmpty,
      onConfirm: () {
        FocusScope.of(context).unfocus();
        Navigator.pop(context, value);
      },
      body: TextField(
        key: const Key('previewDescriptionInput'),
        controller: _controller,
        autofocus: true,
        minLines: 3,
        maxLines: 5,
        maxLength: 200,
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) {
          final submitted = _controller.text.trim();
          if (submitted.isNotEmpty) {
            FocusScope.of(context).unfocus();
            Navigator.pop(context, submitted);
          }
        },
        decoration: InputDecoration(
          hintText: '예: 점심 식사, 병원 방문, 발표 준비',
          filled: true,
          fillColor: const Color(0xFFF6F7F8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _accent, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _AlarmSheet extends StatefulWidget {
  const _AlarmSheet({
    required this.initialMinutes,
    required this.maximumMinutes,
  });

  final int initialMinutes;
  final int maximumMinutes;

  @override
  State<_AlarmSheet> createState() => _AlarmSheetState();
}

class _AlarmSheetState extends State<_AlarmSheet> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialMinutes.clamp(0, widget.maximumMinutes);
  }

  String get _label => _selected == 0 ? '일정 시각에 알림' : '$_selected분 전에 알림';

  @override
  Widget build(BuildContext context) {
    final presets = <int>{0, 5, 10, 15, 20, widget.maximumMinutes}.toList()
      ..sort();
    return _SheetFrame(
      icon: Icons.notifications_active_rounded,
      title: '알림 설정',
      subtitle: _label,
      onConfirm: () => Navigator.pop(context, _selected),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final minutes in presets)
                ChoiceChip(
                  key: Key('alarmPreset-$minutes'),
                  label: Text(minutes == 0 ? '정시' : '$minutes분 전'),
                  selected: _selected == minutes,
                  showCheckmark: false,
                  selectedColor: const Color(0xFFDDF4E9),
                  onSelected: (_) => setState(() => _selected = minutes),
                  labelStyle: TextStyle(
                    color: _selected == minutes ? _accent : _ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F7F8),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Text(
                  _selected == 0 ? '정시' : '$_selected분 전',
                  key: const Key('alarmMinuteValue'),
                  style: const TextStyle(
                    color: _accent,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Slider(
                  key: const Key('alarmMinuteSlider'),
                  value: _selected.toDouble(),
                  min: 0,
                  max: widget.maximumMinutes.toDouble(),
                  divisions: widget.maximumMinutes,
                  activeColor: _accent,
                  label: _selected == 0 ? '정시' : '$_selected분 전',
                  onChanged: (value) =>
                      setState(() => _selected = value.round()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationSheet extends StatefulWidget {
  const _LocationSheet({
    required this.locations,
    required this.selectedLocation,
  });

  final List<ScheduleLocation> locations;
  final ScheduleLocation? selectedLocation;

  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.locations
        .where(
          (location) =>
              location.name.toLowerCase().contains(_query.trim().toLowerCase()),
        )
        .toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD9D9DE),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '장소 선택',
            style: TextStyle(
              color: _ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '저장된 장소를 검색하거나 장소 없이 일정을 만들 수 있어요.',
            style: TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('locationSearchInput'),
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: '장소 이름 검색',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: const Color(0xFFF6F7F8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                _LocationTile(
                  key: const Key('previewLocationNone'),
                  icon: Icons.location_off_rounded,
                  title: '장소 없음',
                  subtitle: '장소를 표시하지 않습니다.',
                  selected: widget.selectedLocation == null,
                  onTap: () =>
                      Navigator.pop(context, (clear: true, location: null)),
                ),
                for (final location in filtered)
                  _LocationTile(
                    key: Key('previewLocation-${location.locationId}'),
                    icon: Icons.place_rounded,
                    title: location.name,
                    subtitle: '저장된 장소',
                    selected:
                        widget.selectedLocation?.locationId ==
                        location.locationId,
                    onTap: () => Navigator.pop(context, (
                      clear: false,
                      location: location,
                    )),
                  ),
                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 26),
                    child: Text(
                      '검색 결과가 없습니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _muted),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF5E5D65),
              side: const BorderSide(color: Color(0xFFE0DFE4)),
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              '닫기',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label),
        onPressed: onTap,
        backgroundColor: selected
            ? const Color(0xFFDDF4E9)
            : const Color(0xFFF3F3F5),
        side: BorderSide.none,
        labelStyle: TextStyle(
          color: selected ? _accent : _ink,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 54,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _accent : Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _muted,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE7F6EF) : const Color(0xFFF7F7F8),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? _accent : _muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded, color: _accent),
            ],
          ),
        ),
      ),
    );
  }
}
