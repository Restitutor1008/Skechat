import 'package:flutter/material.dart';

import '../../models/todo.dart';
import 'schedule_card.dart';

class RecoveryPanel extends StatelessWidget {
  const RecoveryPanel({
    super.key,
    required this.todos,
    required this.use24HourClock,
    required this.onRestore,
    required this.onClose,
  });

  final List<Todo> todos;
  final bool use24HourClock;
  final ValueChanged<int> onRestore;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          key: const Key('recoveryPanel'),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 26, 14, 14),
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
          child: todos.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    '복구할 일정이 없습니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF6F6D76)),
                  ),
                )
              : Column(
                  children: [
                    for (final todo in todos)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ScheduleCard(
                          key: Key('recoverySchedule-${todo.id}'),
                          todo: todo,
                          use24HourClock: use24HourClock,
                          showCheckbox: false,
                          showDate: true,
                          backgroundColor: const Color(0xFFEAF7EF),
                          trailing: IconButton(
                            key: Key('restoreSchedule-${todo.id}'),
                            onPressed: () => onRestore(todo.id),
                            tooltip: '일정 복구',
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFD5F0E0),
                              foregroundColor: const Color(0xFF16845F),
                            ),
                            icon: const Icon(Icons.restore_rounded),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: IconButton(
            key: const Key('closeRecoveryButton'),
            onPressed: onClose,
            tooltip: '복구 목록 닫기',
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
  }
}
