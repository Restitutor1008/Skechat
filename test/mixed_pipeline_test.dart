import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skechat/models/chat_result.dart';
import 'package:skechat/models/todo.dart';
import 'package:skechat/services/local_schedule_text_parser.dart';
import 'package:skechat/views/widgets/schedule_change_preview.dart';
import 'package:skechat/views/widgets/schedule_card.dart';
import 'package:skechat/views/widgets/schedule_edit_sheets.dart';

Todo _todo(int id, String description, int hour) => Todo(
  id: id,
  eta: DateTime(2026, 8, 4, hour),
  description: description,
  user: const ScheduleUser(userId: 'owner', userName: 'owner', phoneNumber: ''),
  alarm: const ScheduleAlarm(
    alarmId: 'alarm',
    alarmMusic: null,
    alarmText: null,
    minutesBefore: 10,
  ),
  location: null,
);

void main() {
  test('오프라인 규칙 분석이 생성 수정 삭제를 한 미리보기로 만든다', () {
    final preview = LocalScheduleTextParser().parse(
      message: '13:30 낮잠 추가, 회의 15:00로 변경, 운동 삭제',
      contextDate: DateTime(2026, 8, 4),
      schedules: [_todo(1, '회의', 14), _todo(2, '운동', 18)],
      pipelineRevision: 7,
    );
    expect(preview, isNotNull);
    expect(preview!.items.map((item) => item.action), [
      PreviewAction.create,
      PreviewAction.update,
      PreviewAction.delete,
    ]);
    expect(preview.items[1].after!.eta!.hour, 15);
  });

  test('정정 표현은 기본 미선택 경고와 확인 질문을 만든다', () {
    final preview = LocalScheduleTextParser().parse(
      message: '회의를 3시가 아니라 4시로 변경',
      contextDate: DateTime(2026, 8, 4),
      schedules: [_todo(1, '회의', 14)],
      pipelineRevision: 8,
    )!;
    expect(preview.items.single.requiresConfirmation, isTrue);
    expect(preview.items.single.selected, isFalse);
    expect(preview.items.single.confirmationQuestion, isNotEmpty);
    expect(preview.items.single.after!.eta!.hour, 4);
  });

  test('시각이 없는 생성 요청은 00시가 아니라 null로 유지한다', () {
    final preview = LocalScheduleTextParser().parse(
      message: '오늘 안에 보고서 작성 추가',
      contextDate: DateTime(2026, 8, 4),
      schedules: const [],
      pipelineRevision: 9,
    )!;
    expect(preview.items.single.after!.eta, isNull);
    expect(preview.items.single.after!.scheduledDate, DateTime(2026, 8, 4));
  });

  testWidgets('경고 항목은 적용 또는 제외 질문에 답하게 한다', (tester) async {
    final item = SchedulePreviewItem(
      itemId: 'warning',
      action: PreviewAction.update,
      scheduleId: 1,
      before: _todo(1, '회의', 14),
      after: _todo(1, '회의', 16),
      selected: false,
      warning: '시간 정정 표현을 감지했습니다.',
      confirmationQuestion: '16:00로 변경할까요?',
      requiresConfirmation: true,
    );
    String? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScheduleChangePreviewCard(
            preview: ScheduleChangePreview(
              operationId: 'mixed',
              action: PreviewAction.mixed,
              items: [item],
            ),
            use24HourClock: true,
            onCancel: () {},
            onApply: () {},
            onResolveItem: (id, apply) => answer = '$id:$apply',
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('batchWarning-warning')), findsOneWidget);
    expect(find.text('16:00로 변경할까요?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('warningApply-warning')));
    expect(answer, 'warning:true');
  });

  testWidgets('시간 null은 미리보기에서 안내하고 실제 카드에서는 비운다', (tester) async {
    final dateOnly = _todo(
      3,
      '오늘 안에',
      0,
    ).copyWith(eta: null, scheduledDate: DateTime(2026, 8, 4));
    await tester.pumpWidget(
      MaterialApp(
        home: ScheduleCard(
          todo: dateOnly,
          use24HourClock: true,
          showEmptyTimeLabel: true,
        ),
      ),
    );
    expect(find.text('시간 미입력'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(home: ScheduleCard(todo: dateOnly, use24HourClock: true)),
    );
    expect(find.text('시간 미입력'), findsNothing);
  });

  testWidgets('혼합 카드마다 개별 OK 버튼이 있고 전체 적용도 유지한다', (tester) async {
    String? applied;
    final items = [
      SchedulePreviewItem(
        itemId: 'one',
        action: PreviewAction.create,
        before: null,
        after: _todo(10, '첫 일정', 10),
        selected: true,
      ),
      SchedulePreviewItem(
        itemId: 'two',
        action: PreviewAction.update,
        before: _todo(11, '둘째 일정', 11),
        after: _todo(11, '변경 일정', 12),
        selected: true,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScheduleChangePreviewCard(
            preview: ScheduleChangePreview(
              operationId: 'mixed-ok',
              action: PreviewAction.mixed,
              items: items,
            ),
            use24HourClock: true,
            onCancel: () {},
            onApply: () {},
            onApplyItem: (id) => applied = id,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('confirmPreviewItem-one')), findsOneWidget);
    expect(find.byKey(const Key('confirmPreviewItem-two')), findsOneWidget);
    expect(find.byKey(const Key('applySelectedPreviewItems')), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmPreviewItem-two')));
    expect(applied, 'two');
  });

  testWidgets('날짜 팝업에서 반복 방식과 복수 요일을 선택한다', (tester) async {
    RecurrenceSelection? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await showScheduleRecurrenceSheet(
                  context,
                  initialDate: DateTime(2026, 8, 4),
                );
              },
              child: const Text('날짜 설정'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('날짜 설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recurrenceMode')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('매주 · 요일 선택').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('weekday-WED')));
    await tester.tap(find.byKey(const Key('scheduleEditorConfirm')));
    await tester.pumpAndSettle();

    expect(result?.rule?.frequency, RoutineFrequency.weekly);
    expect(result?.rule?.weekdays, containsAll(['TUE', 'WED']));
  });

  testWidgets('일정과 루틴이 같은 혼합 미리보기에 표시된다', (tester) async {
    final routineTodo = _todo(20, '월수금 운동', 7);
    final items = [
      SchedulePreviewItem(
        itemId: 'schedule',
        action: PreviewAction.create,
        before: null,
        after: _todo(21, '일회성 약속', 15),
        selected: true,
      ),
      SchedulePreviewItem(
        itemId: 'routine',
        entityType: PreviewEntityType.routine,
        action: PreviewAction.create,
        before: null,
        after: routineTodo,
        routine: RoutinePreviewRule(
          frequency: RoutineFrequency.weekly,
          weekdays: const ['MON', 'WED', 'FRI'],
          startDate: DateTime(2026, 8, 4),
        ),
        selected: true,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScheduleChangePreviewCard(
            preview: ScheduleChangePreview(
              operationId: 'mixed-routine',
              action: PreviewAction.mixed,
              items: items,
            ),
            use24HourClock: true,
            onCancel: () {},
            onApply: () {},
          ),
        ),
      ),
    );

    expect(find.text('생성'), findsOneWidget);
    expect(find.text('루틴'), findsOneWidget);
    expect(find.byKey(const Key('routineRule-routine')), findsOneWidget);
    expect(find.text('매주 월·수·금'), findsOneWidget);
  });
}
