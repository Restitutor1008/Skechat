import 'package:flutter/material.dart';

class CentralServerOfflinePopup extends StatelessWidget {
  const CentralServerOfflinePopup({
    required this.pendingCount,
    required this.nextAttemptAt,
    super.key,
  });

  final int pendingCount;
  final DateTime? nextAttemptAt;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      label: '중앙 서버 연결 끊김',
      child: Material(
        key: const Key('centralServerOfflinePopup'),
        elevation: 10,
        shadowColor: Colors.black45,
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.error.withValues(alpha: 0.4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.error,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_off_rounded,
                  color: colorScheme.onError,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '중앙 서버에 연결할 수 없습니다',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '변경 사항은 이 기기에 안전하게 저장되며, 연결되면 자동으로 동기화됩니다.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onErrorContainer,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _StatusChip(
                          icon: Icons.phone_android_rounded,
                          text: '로컬 모드',
                          color: colorScheme.onErrorContainer,
                        ),
                        _StatusChip(
                          icon: Icons.sync_rounded,
                          text: pendingCount == 0
                              ? '동기화 대기 없음'
                              : '동기화 대기 $pendingCount개',
                          color: colorScheme.onErrorContainer,
                        ),
                        if (nextAttemptAt != null)
                          _StatusChip(
                            icon: Icons.schedule_rounded,
                            text:
                                '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(nextAttemptAt!))} 재시도',
                            color: colorScheme.onErrorContainer,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
