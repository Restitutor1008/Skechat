import 'package:flutter/material.dart';

class ClockFormatToggle extends StatelessWidget {
  const ClockFormatToggle({
    super.key,
    required this.use24HourClock,
    required this.onChanged,
  });

  final bool use24HourClock;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = use24HourClock ? '24h' : '12h';
    return Semantics(
      button: true,
      label: '시간 표시 형식 $label',
      onTap: () => onChanged(!use24HourClock),
      child: Tooltip(
        message: '$label 시간 형식',
        child: InkWell(
          key: const Key('clockFormatToggle'),
          onTap: () => onChanged(!use24HourClock),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: Text(
                    label,
                    key: ValueKey(label),
                    style: const TextStyle(
                      color: Color(0xFF626269),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 46,
                  height: 25,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1AA36F),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    alignment: use24HourClock
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x26000000),
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: SizedBox.square(dimension: 19),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
