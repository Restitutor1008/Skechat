import '../core/config/app_config.dart';
import '../models/chat_result.dart';
import '../models/todo.dart';

class LocalScheduleTextParser {
  static final _time = RegExp(
    r'(?:(오전|오후)\s*)?(\d{1,2})(?::(\d{2})|시(?:\s*(\d{1,2})분)?)',
  );
  static final _date = RegExp(r'(\d{1,2})월\s*(\d{1,2})일');
  static final _crud = RegExp(r'생성|추가|등록|만들|수정|변경|바꿔|삭제|지워|없애');
  static final _correction = RegExp(r'아니라|아니고|말고|정정');

  ScheduleChangePreview? parse({
    required String message,
    required DateTime contextDate,
    required List<Todo> schedules,
    required int pipelineRevision,
  }) {
    final clauses = message
        .split(RegExp(r'\s*(?:,|그리고|그 다음|;|\n)\s*'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    final items = <SchedulePreviewItem>[];
    for (var index = 0; index < clauses.length; index++) {
      final clause = clauses[index].trim();
      final action = _action(clause);
      if (action == null) continue;
      final item = _parseItem(
        clause: clause,
        action: action,
        index: index,
        contextDate: contextDate,
        schedules: schedules,
      );
      if (item != null) items.add(item);
    }
    if (items.isEmpty) return null;
    return ScheduleChangePreview(
      operationId: 'local:mixed:$pipelineRevision',
      action: PreviewAction.mixed,
      pipelineRevision: pipelineRevision,
      items: items,
    );
  }

  PreviewAction? _action(String text) {
    if (RegExp(r'삭제|지워|없애').hasMatch(text)) return PreviewAction.delete;
    if (RegExp(r'수정|변경|바꿔|정정').hasMatch(text)) return PreviewAction.update;
    if (RegExp(r'생성|추가|등록|만들').hasMatch(text)) return PreviewAction.create;
    return null;
  }

  SchedulePreviewItem? _parseItem({
    required String clause,
    required PreviewAction action,
    required int index,
    required DateTime contextDate,
    required List<Todo> schedules,
  }) {
    final warning = _correction.hasMatch(clause)
        ? '정정 표현이 포함되어 최종 값 확인이 필요합니다.'
        : null;
    final requiresConfirmation = warning != null;
    final itemId = 'offline-${index + 1}';
    if (action == PreviewAction.create) {
      final eta = _extractDateTime(clause, contextDate);
      final description = _description(clause);
      if (description.isEmpty) return null;
      final draft = Todo(
        id: -(DateTime.now().microsecondsSinceEpoch + index),
        eta: eta,
        scheduledDate: _extractDate(clause, contextDate),
        description: description,
        user: const ScheduleUser(
          userId: AppConfig.defaultUserId,
          userName: AppConfig.defaultUserId,
          phoneNumber: '',
        ),
        alarm: ScheduleAlarm(
          alarmId: 'offline-preview-$itemId',
          alarmMusic: null,
          alarmText: description,
          minutesBefore: 10,
        ),
        location: null,
      );
      return SchedulePreviewItem(
        itemId: itemId,
        action: action,
        before: null,
        after: draft,
        selected: !requiresConfirmation,
        confidence: requiresConfirmation ? 0.7 : 0.92,
        warning: warning,
        confirmationQuestion: requiresConfirmation
            ? (eta == null
                  ? '$description 일정을 시간 없이 생성할까요?'
                  : '$description 일정을 ${_clock(eta)}에 생성할까요?')
            : null,
        requiresConfirmation: requiresConfirmation,
      );
    }

    final target = _target(clause, schedules);
    if (target == null) return null;
    final clearTime = RegExp(r'시간\s*(?:없이|없음)|오늘\s*안에|언제든').hasMatch(clause);
    final after = action == PreviewAction.update
        ? target.copyWith(
            eta: clearTime
                ? null
                : (_extractDateTime(clause, target.scheduledAt) ?? target.eta),
            description: _replacementDescription(clause) ?? target.description,
          )
        : null;
    return SchedulePreviewItem(
      itemId: itemId,
      action: action,
      scheduleId: target.id,
      before: target,
      after: after,
      selected: !requiresConfirmation,
      confidence: requiresConfirmation ? 0.7 : 0.9,
      warning: warning,
      confirmationQuestion: requiresConfirmation
          ? "'${target.description}' 일정을 표시된 내용대로 ${action == PreviewAction.delete ? '삭제' : '변경'}할까요?"
          : null,
      requiresConfirmation: requiresConfirmation,
    );
  }

  DateTime? _extractDateTime(String text, DateTime base) {
    final matches = _time.allMatches(text).toList();
    final match = matches.isEmpty ? null : matches.last;
    if (match == null) return null;
    var hour = int.parse(match.group(2)!);
    final minute = int.parse(match.group(3) ?? match.group(4) ?? '0');
    if (match.group(1) == '오후' && hour < 12) hour += 12;
    if (match.group(1) == '오전' && hour == 12) hour = 0;
    var year = base.year;
    var month = base.month;
    var day = base.day;
    if (text.contains('내일')) {
      final tomorrow = base.add(const Duration(days: 1));
      year = tomorrow.year;
      month = tomorrow.month;
      day = tomorrow.day;
    } else {
      final dateMatch = _date.firstMatch(text);
      if (dateMatch != null) {
        month = int.parse(dateMatch.group(1)!);
        day = int.parse(dateMatch.group(2)!);
      }
    }
    if (hour > 23 || minute > 59) return null;
    return DateTime(year, month, day, hour, minute);
  }

  DateTime _extractDate(String text, DateTime base) {
    if (text.contains('내일')) {
      final tomorrow = base.add(const Duration(days: 1));
      return DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    }
    final match = _date.firstMatch(text);
    if (match != null) {
      return DateTime(
        base.year,
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
      );
    }
    return DateTime(base.year, base.month, base.day);
  }

  Todo? _target(String clause, List<Todo> schedules) {
    final normalized = clause.replaceAll(_crud, ' ').replaceAll(_time, ' ');
    final candidates = schedules.where((todo) {
      final description = todo.description.trim();
      return description.isNotEmpty && normalized.contains(description);
    }).toList();
    return candidates.length == 1 ? candidates.single : null;
  }

  String _description(String clause) => clause
      .replaceAll(_date, ' ')
      .replaceAll(_time, ' ')
      .replaceAll(RegExp(r'오늘|내일|일정|을|를|에'), ' ')
      .replaceAll(_crud, ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String? _replacementDescription(String clause) {
    final match = RegExp(
      r'내용(?:을|를)?\s*["“]?(.+?)["”]?\s*(?:로|으로)\s*(?:수정|변경|바꿔)',
    ).firstMatch(clause);
    return match?.group(1)?.trim();
  }

  String _clock(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
