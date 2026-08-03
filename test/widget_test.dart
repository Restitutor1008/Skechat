import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skechat/app.dart';
import 'package:skechat/data/repositories/todo_repository.dart';
import 'package:skechat/data/services/api_service.dart';
import 'package:skechat/models/chat_result.dart';
import 'package:skechat/models/todo.dart';
import 'package:skechat/views/widgets/schedule_change_preview.dart';

class FakeTodoRepository extends TodoRepository {
  FakeTodoRepository({
    this.includeCompleted = false,
    this.chatResult,
    this.previewFromMessage = false,
  }) : super(ApiService());

  final bool includeCompleted;
  final ChatResult? chatResult;
  final bool previewFromMessage;
  bool _pendingCompleted = false;
  DateTime? _lastDate;
  Map<String, dynamic>? lastPreviewRevision;
  bool previewCancelled = false;
  final List<String> sentMessages = [];
  final List<int> directlyDeletedIds = [];
  final List<int> restoredIds = [];

  List<Todo> get _deletedTodos => List.generate(
    3,
    (index) => Todo(
      id: 100 + index,
      eta: DateTime(2026, 8, index + 1, 10 + index),
      description: '삭제 일정 ${index + 1}',
      user: const ScheduleUser(
        userId: 'Skechatter',
        userName: 'Skechatter',
        phoneNumber: '010-3120-1319',
      ),
      alarm: ScheduleAlarm(
        alarmId: 'deleted-alarm-$index',
        alarmMusic: null,
        alarmText: '삭제 일정 ${index + 1}',
        minutesBefore: 10,
      ),
      location: null,
      isCompleted: false,
    ),
  ).where((todo) => !restoredIds.contains(todo.id)).toList();

  @override
  Future<List<Todo>> fetchTodos(DateTime date) async {
    _lastDate = date;
    return _todos(date);
  }

  List<Todo> _todos(DateTime date) => [
    if (includeCompleted)
      Todo(
        id: 2,
        eta: DateTime(date.year, date.month, date.day, 9),
        description: '아침 스트레칭',
        user: const ScheduleUser(
          userId: 'Skechatter',
          userName: 'Skechatter',
          phoneNumber: '010-3120-1319',
        ),
        alarm: const ScheduleAlarm(
          alarmId: 'alarm-2',
          alarmMusic: null,
          alarmText: '스트레칭',
          minutesBefore: 10,
        ),
        location: null,
        isCompleted: true,
      ),
    Todo(
      id: 1,
      eta: DateTime(date.year, date.month, date.day, 14),
      description: '가볍게 걷기',
      user: const ScheduleUser(
        userId: 'Skechatter',
        userName: 'Skechatter',
        phoneNumber: '010-3120-1319',
      ),
      alarm: const ScheduleAlarm(
        alarmId: 'alarm-1',
        alarmMusic: 'default',
        alarmText: '운동 시간',
        minutesBefore: 10,
      ),
      location: const ScheduleLocation(
        locationId: 1,
        name: '공원',
        latitude: 37.0,
        longitude: 127.0,
        sourceId: 1,
      ),
      isCompleted: _pendingCompleted,
    ),
  ];

  @override
  Future<Todo> completeTodo(int id) async {
    _pendingCompleted = true;
    return _todos(
      _lastDate ?? DateTime.now(),
    ).firstWhere((todo) => todo.id == id);
  }

  @override
  Future<void> deleteTodo(int id) async => directlyDeletedIds.add(id);

  @override
  Future<List<Todo>> fetchDeletedTodos() async => _deletedTodos;

  @override
  Future<Todo> restoreTodo(int id) async {
    final todo = _deletedTodos.firstWhere((item) => item.id == id);
    restoredIds.add(id);
    return todo;
  }

  @override
  Future<ChatResult> sendMessage(String message) async {
    sentMessages.add(message);
    if (message.trim().toUpperCase() == 'YES') {
      return const ChatResult(message: '일정 변경이 완료되었습니다.');
    }
    if (previewFromMessage) {
      return ChatResult.fromJson({
        'message': '생성할까요?',
        'preview': {
          'operation_id': 'auto-${sentMessages.length}',
          'action': 'create',
          'before_values': <String, dynamic>{},
          'proposed_values': {
            'eta': '2026-08-03T18:00:00+09:00',
            'description': message,
            'alarm_minutes_before': 10,
          },
        },
      });
    }
    return chatResult ?? const ChatResult(message: '일정을 확인했습니다.');
  }

  @override
  Future<void> revisePreview(
    String operationId,
    Map<String, dynamic> changes,
  ) async {
    lastPreviewRevision = changes;
  }

  @override
  Future<void> cancelPreview() async {
    previewCancelled = true;
  }
}

Map<String, dynamic> scheduleJson({
  String description = '기존 일정',
  String eta = '2026-08-03T14:00:00+09:00',
}) => {
  'id': 10,
  'eta': eta,
  'description': description,
  'user': {
    'user_id': 'Skechatter',
    'user_name': 'Skechatter',
    'phone_number': '010-3120-1319',
  },
  'alarm': {
    'alarm_id': 'alarm-10',
    'alarm_music': null,
    'alarm_text': description,
    'minutes_before': 10,
  },
  'location': null,
  'is_completed': false,
};

void main() {
  test('API 타임존 오프셋과 무관하게 일정의 한국 wall-clock 시각을 유지한다', () {
    final todo = Todo.fromJson(scheduleJson(eta: '2026-08-03T23:23:00+09:00'));
    expect(todo.scheduledAt.hour, 23);
    expect(todo.scheduledAt.minute, 23);
  });

  testWidgets('DB 일정이 렌더링되고 시간 형식을 변경한다', (tester) async {
    await tester.pumpWidget(SkeChatApp(repository: FakeTodoRepository()));
    await tester.pumpAndSettle();

    expect(find.text('가볍게 걷기'), findsOneWidget);
    expect(find.byKey(const Key('chatInput')), findsOneWidget);
    final display24h = tester.widget<Text>(
      find.byKey(const Key('scheduleTime')),
    );
    expect(display24h.textSpan?.toPlainText(), '14:00 PM');
    final rootSpan24h = display24h.textSpan as TextSpan;
    final period24h = rootSpan24h.children?[1] as TextSpan;
    expect(period24h.style?.color, Colors.transparent);
    final timeCenter24h = tester.getCenter(
      find.byKey(const Key('scheduleTime')),
    );

    expect(find.text('24h'), findsOneWidget);
    await tester.tap(find.byKey(const Key('clockFormatToggle')));
    await tester.pumpAndSettle();

    expect(find.text('12h'), findsOneWidget);
    final display12h = tester.widget<Text>(
      find.byKey(const Key('scheduleTime')),
    );
    expect(display12h.textSpan?.toPlainText(), '02:00 PM');
    final rootSpan12h = display12h.textSpan as TextSpan;
    final period12h = rootSpan12h.children?[1] as TextSpan;
    expect(period12h.style?.color, const Color(0xFF26262C));
    final timeCenter12h = tester.getCenter(
      find.byKey(const Key('scheduleTime')),
    );
    expect(timeCenter12h, timeCenter24h);
  });

  testWidgets('좁은 화면에서도 주요 UI가 표시된다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(SkeChatApp(repository: FakeTodoRepository()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('schedulePanel')), findsOneWidget);
    expect(find.byKey(const Key('chatComposer')), findsOneWidget);

    final panelRect = tester.getRect(find.byKey(const Key('schedulePanel')));
    final dateRect = tester.getRect(find.byKey(const Key('dateTitle')));
    final toggleRect = tester.getRect(
      find.byKey(const Key('clockFormatToggle')),
    );
    expect((dateRect.center.dx - panelRect.center.dx).abs(), lessThan(0.5));
    expect(toggleRect.top, greaterThan(dateRect.bottom));
  });

  testWidgets('완료 일정은 개수 표시 없이 할 일보다 위에 흐리게 표시한다', (tester) async {
    await tester.pumpWidget(
      SkeChatApp(repository: FakeTodoRepository(includeCompleted: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('완료된 일정 1개'), findsNothing);
    expect(find.text('할 일 1개'), findsOneWidget);
    final completedOpacity = tester.widget<Opacity>(
      find.byKey(const Key('completedSchedule-2')),
    );
    expect(completedOpacity.opacity, 0.48);
    final completedCheckbox = tester.widget<Checkbox>(
      find.byKey(const Key('scheduleCheckbox-2')),
    );
    expect(completedCheckbox.value, isTrue);
    expect(completedCheckbox.onChanged, isNull);
    expect(
      tester.getTopLeft(find.text('아침 스트레칭')).dy,
      lessThan(tester.getTopLeft(find.text('가볍게 걷기')).dy),
    );

    await tester.tap(find.byKey(const Key('scheduleCheckbox-2')));
    await tester.pump();
    expect(find.text('할 일 1개'), findsOneWidget);

    await tester.tap(find.byKey(const Key('scheduleCheckbox-1')));
    await tester.pumpAndSettle();
    expect(find.text('할 일 0개'), findsOneWidget);
    expect(
      tester
          .widget<Checkbox>(find.byKey(const Key('scheduleCheckbox-1')))
          .value,
      isTrue,
    );
    expect(find.byKey(const Key('completedSchedule-1')), findsOneWidget);
  });

  testWidgets('Create 채팅 미리보기를 할 일 아래 연한 초록색으로 표시한다', (tester) async {
    final result = ChatResult.fromJson({
      'message': '생성할까요?',
      'preview': {
        'operation_id': 'create-op',
        'action': 'create',
        'before_values': <String, dynamic>{},
        'proposed_values': {
          'eta': '2026-08-03T18:00:00+09:00',
          'description': '책 읽기',
          'alarm_minutes_before': 10,
        },
      },
    });
    await tester.pumpWidget(
      SkeChatApp(repository: FakeTodoRepository(chatResult: result)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('confirmPreviewButton')), findsNothing);
    await tester.enterText(find.byKey(const Key('chatInput')), '책 읽기 추가');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump(const Duration(milliseconds: 500));

    final preview = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const Key('createPreviewCard')),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(
      (preview.decoration as BoxDecoration).color,
      const Color(0xFFEAF7EF),
    );
    expect(find.text('책 읽기'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('책 읽기')).dy,
      greaterThan(tester.getTopLeft(find.text('가볍게 걷기')).dy),
    );
    expect(find.byKey(const Key('assistantResponse')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('schedulePanel')),
        matching: find.byKey(const Key('createPreviewCard')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('chatResponseArea')),
        matching: find.byKey(const Key('createPreviewCard')),
      ),
      findsOneWidget,
    );
    expect(
      tester.getBottomLeft(find.byKey(const Key('chatResponseArea'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('chatComposer'))).dy),
    );
    expect(find.text('OK!'), findsOneWidget);
    final scaleSamples = <String>{};
    for (var index = 0; index < 10; index++) {
      await tester.pump(const Duration(milliseconds: 150));
      final value = tester
          .widget<ScaleTransition>(
            find.byKey(const Key('confirmPreviewButton')),
          )
          .scale
          .value;
      scaleSamples.add(value.toStringAsFixed(3));
    }
    expect(scaleSamples.length, greaterThan(1));
    final repository =
        (tester.widget<SkeChatApp>(find.byType(SkeChatApp))).repository
            as FakeTodoRepository;
    await tester.tap(find.byKey(const Key('confirmPreviewButton')));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(repository.sentMessages, contains('YES'));
    expect(find.byKey(const Key('confirmPreviewButton')), findsNothing);
  });

  testWidgets('알 수 없음 응답만 입력창 위에 문장으로 표시한다', (tester) async {
    final repository = FakeTodoRepository(
      chatResult: const ChatResult(
        message: '스케줄 시각을 알 수 없습니다.',
        errorCode: 'MISSING_SCHEDULE_TIME',
      ),
    );
    await tester.pumpWidget(SkeChatApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('chatInput')), '공부하기');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('assistantResponse')), findsOneWidget);
    expect(find.text('스케줄 시각을 알 수 없습니다.'), findsOneWidget);
    expect(find.byKey(const Key('createPreviewCard')), findsNothing);
    expect(
      tester.getBottomLeft(find.byKey(const Key('assistantResponse'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('chatComposer'))).dy),
    );
  });

  testWidgets('Update는 위아래 카드, Delete는 연한 빨간색으로 표시한다', (tester) async {
    var updateTimeTapped = false;
    final update = ScheduleChangePreview.fromJson({
      'operation_id': 'update-op',
      'action': 'update',
      'before_values': scheduleJson(),
      'proposed_values': {
        'eta': '2026-08-03T16:00:00+09:00',
        'description': '변경 일정',
      },
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScheduleChangePreviewCard(
            preview: update,
            use24HourClock: true,
            onCancel: () {},
            onApply: () {},
            onEditTime: () => updateTimeTapped = true,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('updateBeforeCard')), findsOneWidget);
    expect(find.byKey(const Key('updateAfterCard')), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('기존 일정')).dy,
      lessThan(tester.getTopLeft(find.text('변경 일정')).dy),
    );
    final originalOpacity = tester.widget<Opacity>(
      find.ancestor(
        of: find.byKey(const Key('updateBeforeCard')),
        matching: find.byType(Opacity),
      ),
    );
    expect(originalOpacity.opacity, 0.58);
    expect(
      tester.widget<InkWell>(find.byKey(const Key('updateBefore-time'))).onTap,
      isNull,
    );
    expect(
      tester.getCenter(find.byKey(const Key('updateAfter-date'))).dx,
      greaterThan(
        tester.getCenter(find.byKey(const Key('updateAfter-time'))).dx,
      ),
    );
    await tester.tap(find.byKey(const Key('updateAfter-time')));
    expect(updateTimeTapped, isTrue);

    final deletion = ScheduleChangePreview.fromJson({
      'operation_id': 'delete-op',
      'action': 'delete',
      'before_values': scheduleJson(),
      'proposed_values': <String, dynamic>{},
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScheduleChangePreviewCard(
            preview: deletion,
            use24HourClock: true,
            onCancel: () {},
            onApply: () {},
          ),
        ),
      ),
    );
    final deleteCard = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const Key('deletePreviewCard')),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(
      (deleteCard.decoration as BoxDecoration).color,
      const Color(0xFFFCECEC),
    );
  });

  testWidgets('미리보기 필드를 편집하고 X로 서버 대기 작업을 취소한다', (tester) async {
    final result = ChatResult.fromJson({
      'message': '생성할까요?',
      'preview': {
        'operation_id': 'editable-op',
        'action': 'create',
        'before_values': <String, dynamic>{},
        'proposed_values': {
          'eta': '2026-08-03T18:00:00+09:00',
          'description': '책 읽기',
          'alarm_minutes_before': 10,
        },
      },
    });
    final repository = FakeTodoRepository(chatResult: result);
    await tester.pumpWidget(SkeChatApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('chatInput')), '책 읽기 추가');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byKey(const Key('createPreview-description')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(
      find.byKey(const Key('previewDescriptionInput')),
      '수정된 책 읽기',
    );
    await tester.tap(find.widgetWithText(FilledButton, '확인'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('수정된 책 읽기'), findsOneWidget);
    expect(repository.lastPreviewRevision, {'description': '수정된 책 읽기'});

    await tester.tap(find.byKey(const Key('createPreview-date')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('취소').last);
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byKey(const Key('createPreview-time')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('취소').last);
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byKey(const Key('createPreview-alarm')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('alarmMinutePicker')), findsOneWidget);
    final alarmPicker = tester.widget<ListWheelScrollView>(
      find.byKey(const Key('alarmMinutePicker')),
    );
    expect(alarmPicker.childDelegate.estimatedChildCount, 31);
    await tester.tap(find.text('취소').last);
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byKey(const Key('cancelPreviewButton')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('createPreviewCard')), findsNothing);
    expect(repository.previewCancelled, isTrue);
  });

  testWidgets('공백은 무시하고 입력 중단 0.5초 후 미리보기를 교체한다', (tester) async {
    final repository = FakeTodoRepository(previewFromMessage: true);
    await tester.pumpWidget(SkeChatApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('chatInput')), '   ');
    await tester.pump(const Duration(seconds: 4));
    expect(repository.sentMessages, isEmpty);

    await tester.enterText(find.byKey(const Key('chatInput')), '첫 일정');
    await tester.pump(const Duration(milliseconds: 499));
    expect(repository.sentMessages, isEmpty);
    await tester.pump(const Duration(milliseconds: 2));
    await tester.pump();
    expect(repository.sentMessages, ['첫 일정']);
    expect(
      find.descendant(
        of: find.byKey(const Key('createPreviewCard')),
        matching: find.text('첫 일정'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('confirmPreviewButton')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('chatInput')), '둘째 일정');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 499));
    expect(find.byKey(const Key('confirmPreviewButton')), findsNothing);
    expect(repository.sentMessages, hasLength(1));
    await tester.pump(const Duration(milliseconds: 2));
    await tester.pump();
    expect(repository.sentMessages, ['첫 일정', '둘째 일정']);
    expect(repository.previewCancelled, isTrue);
    expect(
      find.descendant(
        of: find.byKey(const Key('createPreviewCard')),
        matching: find.text('둘째 일정'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('confirmPreviewButton')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('chatInput')), '     ');
    await tester.pump(const Duration(seconds: 4));
    expect(repository.sentMessages, hasLength(2));
  });

  testWidgets('스와이프 삭제는 REST 저장소를 직접 호출하고 복구 목록을 표시한다', (tester) async {
    final repository = FakeTodoRepository();
    await tester.pumpWidget(SkeChatApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.drag(find.text('가볍게 걷기'), const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('swipeDelete-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('swipeDelete-1')));
    await tester.pumpAndSettle();
    expect(repository.directlyDeletedIds, [1]);
    expect(find.text('가볍게 걷기'), findsNothing);

    await tester.enterText(find.byKey(const Key('chatInput')), '복구');
    await tester.pump(const Duration(milliseconds: 501));
    await tester.pump();
    expect(find.byKey(const Key('recoveryPanel')), findsOneWidget);
    expect(find.byKey(const Key('recoverySchedule-100')), findsOneWidget);
    expect(find.byKey(const Key('recoverySchedule-102')), findsOneWidget);

    await tester.tap(find.byKey(const Key('restoreSchedule-100')));
    await tester.pumpAndSettle();
    expect(repository.restoredIds, [100]);
  });
}
