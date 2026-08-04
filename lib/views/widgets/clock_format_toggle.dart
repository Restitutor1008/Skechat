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
    final label = use24HourClock ? '24시간' : '오전·오후';
    return Semantics(
      button: true,
      label: '시간 표시 방식 $label',
      onTap: () => onChanged(!use24HourClock),
      child: Tooltip(
        message: '$label 시간 표시',
        child: InkWell(
          key: const Key('clockFormatToggle'),
          onTap: () => onChanged(!use24HourClock),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 58,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 360),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.25),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Text(
                      label,
                      key: ValueKey(label),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Color(0xFF626269),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 48,
                  height: 26,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1AA36F),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeInOutCubic,
                    alignment: use24HourClock
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: const DecoratedBox(
                      key: Key('clockFormatThumb'),
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
                      child: SizedBox.square(dimension: 20),
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
