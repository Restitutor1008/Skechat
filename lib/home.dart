import 'package:flutter/material.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  DateTime _selectedDate = DateTime(2026, 7, 16);
  bool _use24HourClock = true;

  static const List<_Schedule> _schedules = [
    _Schedule(
      hour: 8,
      minute: 0,
      title: '헬스장',
      description: '아침 운동으로 하루 시작하기',
      color: Color(0xFFF4F2FC),
      accentColor: Color(0xFF8D7ED8),
    ),
    _Schedule(
      hour: 14,
      minute: 0,
      title: '치과 예약',
      description: '예약 시간 10분 전에 알림',
      color: Color(0xFFFFF8F0),
      accentColor: Color(0xFFE6A65D),
    ),
  ];

  Future<void> _openCalendar() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(DateTime.now().year - 10),
      lastDate: DateTime(DateTime.now().year + 10),
      helpText: '날짜 선택',
      cancelText: '취소',
      confirmText: '확인',
    );
    if (date != null && mounted) {
      setState(() => _selectedDate = date);
    }
  }

  void _moveDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final horizontalMargin = width >= 900
                ? 40.0
                : width >= 600
                ? 28.0
                : 16.0;
            final topMargin = width >= 600 ? 36.0 : 20.0;
            final cardPadding = width >= 600 ? 32.0 : 20.0;

            return Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalMargin,
                topMargin,
                horizontalMargin,
                12,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Container(
                            key: const Key('schedulePanel'),
                            width: double.infinity,
                            padding: EdgeInsets.fromLTRB(
                              cardPadding,
                              cardPadding,
                              cardPadding,
                              cardPadding + 6,
                            ),
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
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _YearHeader(
                                  year: _selectedDate.year,
                                  onCalendarPressed: _openCalendar,
                                ),
                                const SizedBox(height: 10),
                                _DateNavigation(
                                  date: _selectedDate,
                                  scheduleCount: _schedules.length,
                                  onPrevious: () => _moveDate(-1),
                                  onNext: () => _moveDate(1),
                                ),
                                const SizedBox(height: 18),
                                ..._schedules.map(
                                  (schedule) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _ScheduleCard(
                                      schedule: schedule,
                                      use24HourClock: _use24HourClock,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const _ScheduleHint(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: _ChatComposer(
                        use24HourClock: _use24HourClock,
                        onClockFormatChanged: (value) {
                          setState(() => _use24HourClock = value);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _YearHeader extends StatelessWidget {
  const _YearHeader({required this.year, required this.onCalendarPressed});

  final int year;
  final VoidCallback onCalendarPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Text(
              '$year년',
              style: const TextStyle(
                color: Color(0xFF202026),
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
          ),
          Positioned(
            right: 0,
            child: IconButton(
              key: const Key('calendarButton'),
              onPressed: onCalendarPressed,
              tooltip: '달력 열기',
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF3F2F7),
                foregroundColor: const Color(0xFF25252B),
              ),
              icon: const Icon(Icons.calendar_month_rounded, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateNavigation extends StatelessWidget {
  const _DateNavigation({
    required this.date,
    required this.scheduleCount,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime date;
  final int scheduleCount;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ArrowButton(
          key: const Key('previousDateButton'),
          icon: Icons.chevron_left_rounded,
          tooltip: '이전 날짜',
          onPressed: onPrevious,
        ),
        Expanded(
          child: Text(
            '${date.month}월 ${date.day}일',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF202026),
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
        ),
        _ArrowButton(
          key: const Key('nextDateButton'),
          icon: Icons.chevron_right_rounded,
          tooltip: '다음 날짜',
          onPressed: onNext,
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF28282E),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            '$scheduleCount개',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      constraints: const BoxConstraints.tightFor(width: 42, height: 42),
      icon: Icon(icon, size: 27),
      color: const Color(0xFF28282E),
    );
  }
}

class _ClockFormatPicker extends StatelessWidget {
  const _ClockFormatPicker({
    required this.use24HourClock,
    required this.onChanged,
  });

  final bool use24HourClock;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '시간 표시 형식',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FormatCircle(
            key: const Key('24HourButton'),
            label: '24',
            selected: use24HourClock,
            onTap: () => onChanged(true),
          ),
          const SizedBox(width: 4),
          _FormatCircle(
            key: const Key('12HourButton'),
            label: '12',
            selected: !use24HourClock,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _FormatCircle extends StatelessWidget {
  const _FormatCircle({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label시간제',
      child: Tooltip(
        message: '$label시간제로 표시',
        child: Material(
          color: selected ? const Color(0xFF1AA36F) : const Color(0xFFF1F1F4),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox.square(
              dimension: 32,
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF777780),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.schedule, required this.use24HourClock});

  final _Schedule schedule;
  final bool use24HourClock;

  String get _time {
    if (use24HourClock) {
      return '${schedule.hour.toString().padLeft(2, '0')}:'
          '${schedule.minute.toString().padLeft(2, '0')}';
    }
    final hour = schedule.hour % 12 == 0 ? 12 : schedule.hour % 12;
    return '${hour.toString().padLeft(2, '0')}:'
        '${schedule.minute.toString().padLeft(2, '0')}';
  }

  String get _period => schedule.hour < 12 ? '오전' : '오후';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      decoration: BoxDecoration(
        color: schedule.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: schedule.accentColor.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!use24HourClock)
                    Text(
                      _period,
                      style: TextStyle(
                        color: schedule.accentColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  Text(
                    _time,
                    style: const TextStyle(
                      color: Color(0xFF2A2A30),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF2A2A30),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  schedule.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF84838B),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: schedule.accentColor.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '예정',
              style: TextStyle(
                color: schedule.accentColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleHint extends StatelessWidget {
  const _ScheduleHint();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 5),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFF8D7ED8),
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(dimension: 6),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '시간을 바꾸거나 새 일정을 알림해보세요.',
              style: TextStyle(
                color: Color(0xFF8A8991),
                fontSize: 11,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.use24HourClock,
    required this.onClockFormatChanged,
  });

  final bool use24HourClock;
  final ValueChanged<bool> onClockFormatChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('chatComposer'),
      padding: const EdgeInsets.fromLTRB(8, 7, 7, 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE9E9ED)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x190F172A),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _ClockFormatPicker(
            use24HourClock: use24HourClock,
            onChanged: onClockFormatChanged,
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 24, color: const Color(0xFFE7E7EB)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: const Key('chatInput'),
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) {},
              style: const TextStyle(
                color: Color(0xFF2A2A30),
                fontSize: 14,
                height: 1.3,
              ),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Sketch your day with SkeChat!',
                hintStyle: TextStyle(color: Color(0xFFA3A2AA), fontSize: 13),
                contentPadding: EdgeInsets.symmetric(vertical: 11),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Semantics(
            button: true,
            label: '메시지 보내기',
            child: IconButton(
              key: const Key('sendMessageButton'),
              onPressed: () {},
              tooltip: '보내기',
              style: IconButton.styleFrom(
                fixedSize: const Size.square(42),
                minimumSize: const Size.square(42),
                backgroundColor: const Color(0xFF1AA36F),
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
              ),
              icon: const Icon(Icons.arrow_upward_rounded, size: 21),
            ),
          ),
        ],
      ),
    );
  }
}

class _Schedule {
  const _Schedule({
    required this.hour,
    required this.minute,
    required this.title,
    required this.description,
    required this.color,
    required this.accentColor,
  });

  final int hour;
  final int minute;
  final String title;
  final String description;
  final Color color;
  final Color accentColor;
}
