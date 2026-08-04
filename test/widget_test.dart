import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skechat/app.dart';
import 'package:skechat/data/repositories/todo_repository.dart';
import 'package:skechat/data/services/api_service.dart';
import 'package:skechat/models/chat_result.dart';
import 'package:skechat/models/todo.dart';
import 'package:skechat/views/widgets/schedule_change_preview.dart';
import 'package:skechat/views/widgets/schedule_card.dart';

class FakeTodoRepository extends TodoRepository {
  FakeTodoRepository({
    this.includeCompleted = false,
    this.chatResult,
    this.previewFromMessage = false,
    this.delayedCallNumber,
    this.chatDelay = Duration.zero,
    this.chatError,
    this.reverseOrder = false,
    this.syncError,
    this.emptySchedules = false,
    this.timeoutCallNumbers = const <int>{},
  }) : super(ApiService());

  final bool includeCompleted;
  final ChatResult? chatResult;
  final bool previewFromMessage;
  final int? delayedCallNumber;
  final Duration chatDelay;
  final Object? chatError;
  final bool reverseOrder;
  final Object? syncError;
  final bool emptySchedules;
  final Set<int> timeoutCallNumbers;
  final Map<int, bool> _completionOverrides = {};
  DateTime? _lastDate;
  Map<String, dynamic>? lastPreviewRevision;
  bool previewCancelled = false;
  final List<String> sentMessages = [];
  final List<DateTime> sentContextDates = [];
  final List<int> sentPipelineRevisions = [];
  final List<int> directlyDeletedIds = [];
  final List<int> restoredIds = [];
  final List<DateTime> blankCreateDates = [];
  final List<Todo> locallyCreatedTodos = [];
  final List<Todo> locallyUpdatedTodos = [];
  final List<String> selectedPreviewItemIds = [];

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

  List<Todo> _todos(DateTime date) {
    if (emptySchedules) return const [];
    final items = [
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
          isCompleted: _completionOverrides[2] ?? true,
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
        isCompleted: _completionOverrides[1] ?? false,
      ),
    ];
    return reverseOrder ? items.reversed.toList() : items;
  }

  @override
  Future<Todo> setTodoCompleted(int id, bool isCompleted) async {
    _completionOverrides[id] = isCompleted;
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
  Future<ChatResult> sendMessage(
    String message,
    DateTime contextDate, {
    required int pipelineRevision,
    String? pipelineOperationId,
  }) async {
    sentMessages.add(message);
    sentContextDates.add(contextDate);
    sentPipelineRevisions.add(pipelineRevision);
    if (timeoutCallNumbers.contains(sentMessages.length)) {
      throw const ApiTimeoutException();
    }
    if (sentMessages.length == delayedCallNumber) {
      await Future<void>.delayed(chatDelay);
      if (chatError case final error?) throw error;
    }
    if (message.trim().toUpperCase() == 'YES') {
      return const ChatResult(message: '일정 변경이 완료되었습니다.');
    }
    if (previewFromMessage) {
      return ChatResult.fromJson({
        'message': '생성할까요?',
        'preview': {
          'operation_id': 'active-pipeline',
          'pipeline_revision': pipelineRevision,
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
  Future<void> cancelPreview(String operationId) async {
    previewCancelled = true;
  }

  @override
  Future<void> selectPreviewItems(
    String operationId,
    List<String> selectedItemIds, [
    List<String> confirmedItemIds = const <String>[],
  ]) async {
    selectedPreviewItemIds
      ..clear()
      ..addAll(selectedItemIds);
  }

  @override
  Future<ScheduleChangePreview> startBlankCreatePreview(
    DateTime date,
    int pipelineRevision,
  ) async {
    blankCreateDates.add(date);
    return ScheduleChangePreview.fromJson({
      'operation_id': 'manual-create-pipeline',
      'pipeline_revision': pipelineRevision,
      'action': 'create',
      'before_values': <String, dynamic>{},
      'proposed_values': {
        'eta': DateTime(date.year, date.month, date.day).toIso8601String(),
        'description': '',
        'location_id': null,
        'alarm_minutes_before': 10,
      },
    });
  }

  @override
  Future<Todo> createLocalTodo(Todo draft) async {
    final saved = draft.copyWith(id: -1000 - locallyCreatedTodos.length);
    locallyCreatedTodos.add(saved);
    return saved;
  }

  @override
  Future<Todo> updateLocalTodo(Todo todo) async {
    locallyUpdatedTodos.add(todo);
    return todo;
  }

  @override
  Future<List<ScheduleLocation>> fetchLocations() async => const [
    ScheduleLocation(
      locationId: 1,
      name: '공원',
      latitude: 37,
      longitude: 127,
      sourceId: 1,
    ),
  ];

  @override
  Future<TodoSyncResult> synchronize({bool uploadPending = true}) async {
    if (syncError case final error?) throw error;
    return const TodoSyncResult(changed: false, pendingCount: 0);
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
  test('REST 요청 시간이 초과되면 전용 timeout 오류를 반환한다', () async {
    final api = ApiService(
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return http.Response('[]', 200);
      }),
      requestTimeout: const Duration(milliseconds: 1),
    );

    await expectLater(
      api.getList('/api/todos'),
      throwsA(isA<ApiTimeoutException>()),
    );
  });

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
    expect(
      tester.getSize(find.byKey(const Key('scheduleCardSurface-1'))).height,
      lessThanOrEqualTo(52),
    );
    expect(
      tester.getCenter(find.byKey(const Key('todoCount'))).dy,
      closeTo(
        tester.getCenter(find.byKey(const Key('clockFormatToggle'))).dy,
        0.1,
      ),
    );

    expect(find.text('24시간'), findsOneWidget);
    final thumb24h = tester.getCenter(
      find.byKey(const Key('clockFormatThumb')),
    );
    await tester.tap(find.byKey(const Key('clockFormatToggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final thumbDuringTransition = tester.getCenter(
      find.byKey(const Key('clockFormatThumb')),
    );
    await tester.pumpAndSettle();
    final thumb12h = tester.getCenter(
      find.byKey(const Key('clockFormatThumb')),
    );
    expect(thumbDuringTransition.dx, lessThan(thumb24h.dx));
    expect(thumbDuringTransition.dx, greaterThan(thumb12h.dx));

    expect(find.text('오전·오후'), findsOneWidget);
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

  testWidgets('장소가 없는 일정은 장소 문구를 숨기고 선택된 주간 날짜를 강조한다', (tester) async {
    final repository = FakeTodoRepository(includeCompleted: true);
    await tester.pumpWidget(SkeChatApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('장소 없음'), findsNothing);
    expect(find.textContaining('공원'), findsWidgets);

    final weekSelector = find.byKey(const Key('weekDateSelector'));
    expect(weekSelector, findsOneWidget);
    for (final label in ['월', '화', '수', '목', '금', '토', '일']) {
      expect(
        find.descendant(of: weekSelector, matching: find.text(label)),
        findsOneWidget,
      );
    }
    expect(find.byKey(const Key('selectedWeekDate')), findsOneWidget);
    final selectedDecoration =
        tester
                .widget<Container>(find.byKey(const Key('selectedWeekDate')))
                .decoration
            as BoxDecoration;
    expect(selectedDecoration.color, const Color(0xFF1AA36F));

    final current = DateTime.now();
    final selected = DateTime(current.year, current.month, current.day);
    final monday = selected.subtract(Duration(days: selected.weekday - 1));
    final target = selected.weekday == DateTime.monday
        ? monday.add(const Duration(days: 1))
        : monday;
    final targetKey =
        '${target.year.toString().padLeft(4, '0')}-'
        '${target.month.toString().padLeft(2, '0')}-'
        '${target.day.toString().padLeft(2, '0')}';
    await tester.tap(find.byKey(Key('weekDate-$targetKey')));
    await tester.pumpAndSettle();

    expect(repository._lastDate, target);
    expect(find.byKey(const Key('selectedWeekDate')), findsOneWidget);
  });

  testWidgets('한국 공휴일은 빨간색이며 요일과 날짜를 셀 가운데에 배치한다', (tester) async {
    final repository = FakeTodoRepository();
    await tester.pumpWidget(SkeChatApp(repository: repository));
    await tester.pumpAndSettle();

    final start = repository._lastDate!;
    final targetDay = DateTime(2026, 8, 14);
    final moves = targetDay.difference(start).inDays;
    expect(moves, greaterThanOrEqualTo(0));
    for (var index = 0; index < moves; index++) {
      await tester.tap(find.byKey(const Key('nextDateButton')));
      await tester.pumpAndSettle();
    }

    final holidayCell = find.byKey(const Key('weekDate-2026-08-15'));
    expect(holidayCell, findsOneWidget);
    final holidayStyles = tester.widgetList<AnimatedDefaultTextStyle>(
      find.descendant(
        of: holidayCell,
        matching: find.byType(AnimatedDefaultTextStyle),
      ),
    );
    expect(holidayStyles, hasLength(2));
    for (final style in holidayStyles) {
      expect(style.style.color, const Color(0xFFC53E4A));
    }

    final weekdayRect = tester.getRect(
      find.descendant(of: holidayCell, matching: find.text('토')),
    );
    final dayRect = tester.getRect(
      find.descendant(of: holidayCell, matching: find.text('15')),
    );
    final contentCenter = (weekdayRect.top + dayRect.bottom) / 2;
    expect(contentCenter, closeTo(tester.getRect(holidayCell).center.dy, 0.5));
  });

  testWidgets('일정이 없으면 상태 조작부를 숨기고 흰 패널 높이를 줄인다', (tester) async {
    await tester.pumpWidget(
      SkeChatApp(repository: FakeTodoRepository(emptySchedules: true)),
    );
    await tester.pumpAndSettle();

    final emptyHeight = tester
        .getSize(find.byKey(const Key('schedulePanel')))
        .height;
    expect(find.byKey(const Key('todoCount')), findsNothing);
    expect(find.byKey(const Key('clockFormatToggle')), findsNothing);
    expect(find.text('등록된 일정이 없습니다.'), findsNothing);
    expect(find.byKey(const Key('addScheduleButton')), findsOneWidget);

    await tester.pumpWidget(SkeChatApp(repository: FakeTodoRepository()));
    await tester.pumpAndSettle();
    final populatedHeight = tester
        .getSize(find.byKey(const Key('schedulePanel')))
        .height;
    expect(populatedHeight, greaterThan(emptyHeight));
  });

  testWidgets('일정 추가 버튼은 빈 CREATE 파이프라인을 시작한다', (tester) async {
    final repository = FakeTodoRepository(emptySchedules: true);
    await tester.pumpWidget(SkeChatApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('addScheduleButton')));
    await tester.pumpAndSettle();

    expect(repository.blankCreateDates, isEmpty);
    expect(find.byKey(const Key('createPreviewCard')), findsOneWidget);
    expect(find.text('일정 내용을 입력하세요'), findsOneWidget);
    final previewDate = tester.getRect(
      find.byKey(const Key('createPreview-date')),
    );
    final previewSurface = tester.getRect(
      find.byKey(const Key('createPreview-cardSurface')),
    );
    expect(previewDate.bottom, lessThan(previewSurface.top));
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('chatInput')))
          .controller!
          .text,
      '새로운 일정 생성',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('scheduleTime')))
          .textSpan
          ?.toPlainText(),
      '시간 미입력',
    );
    expect(find.textContaining('장소 없음'), findsOneWidget);
    expect(find.text('10분 전 알림'), findsOneWidget);

    await tester.tap(find.byKey(const Key('createPreview-location')));
    await tester.pumpAndSettle();
    expect(find.text('장소 선택'), findsOneWidget);
    await tester.tap(find.byKey(const Key('previewLocation-1')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('공원'), findsWidgets);
    expect(repository.lastPreviewRevision, isNull);

    final disabledButton = tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const Key('confirmPreviewButton')),
        matching: find.byType(InkWell),
      ),
    );
    expect(disabledButton.onTap, isNull);

    await tester.tap(find.byKey(const Key('createPreview-description')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('previewDescriptionInput')),
      '새 일정',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('confirmPreviewButton')));
    await tester.pumpAndSettle();

    expect(repository.sentMessages, isNot(contains('YES')));
    expect(repository.locallyCreatedTodos, hasLength(1));
    expect(repository.locallyCreatedTodos.single.description, '새 일정');
    expect(repository.locallyCreatedTodos.single.location?.name, '공원');
    expect(find.byKey(const Key('createPreviewCard')), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('chatInput')))
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('기존 일정 카드를 누르면 로컬 수정 미리보기를 연다', (tester) async {
    final repository = FakeTodoRepository();
    await tester.pumpWidget(SkeChatApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('scheduleCardSurface-1')));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('updatePreviewCards')), findsOneWidget);
    expect(find.byKey(const Key('updateBeforeCard')), findsOneWidget);
    expect(find.byKey(const Key('updateAfterCard')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('chatInput')))
          .controller!
          .text,
      '일정 수정',
    );
  });

  testWidgets('날짜 이동 방향에 따라 일정 목록이 반대 방향으로 퇴장한다', (tester) async {
    final repository = FakeTodoRepository();
    await tester.pumpWidget(SkeChatApp(repository: repository));
    await tester.pumpAndSettle();

    double horizontalTranslation() => tester
        .widgetList<Transform>(
          find.descendant(
            of: find.byKey(const Key('scheduleTransitionLayer')),
            matching: find.byType(Transform),
          ),
        )
        .map((transform) => transform.transform.storage[12])
        .firstWhere((value) => value.abs() > 0.01);

    final addRect = tester.getRect(find.byKey(const Key('addScheduleButton')));
    final countRect = tester.getRect(find.byKey(const Key('todoCount')));
    final toggleRect = tester.getRect(
      find.byKey(const Key('clockFormatToggle')),
    );

    await tester.tap(find.byKey(const Key('nextDateButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 130));
    expect(horizontalTranslation(), lessThan(0));
    expect(tester.getRect(find.byKey(const Key('addScheduleButton'))), addRect);
    expect(tester.getRect(find.byKey(const Key('todoCount'))), countRect);
    expect(
      tester.getRect(find.byKey(const Key('clockFormatToggle'))),
      toggleRect,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('previousDateButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 130));
    expect(horizontalTranslation(), greaterThan(0));
    await tester.pumpAndSettle();
  });

  testWidgets('API 순서와 무관하게 할 일 다음에 완료된 일을 쌓는다', (tester) async {
    await tester.pumpWidget(
      SkeChatApp(
        repository: FakeTodoRepository(
          includeCompleted: true,
          reverseOrder: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scheduleHours = tester
        .widgetList<ScheduleCard>(find.byType(ScheduleCard))
        .map((card) => card.todo.scheduledAt.hour)
        .toList();
    expect(scheduleHours, [14, 9]);
    expect(find.byType(SingleChildScrollView), findsWidgets);
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
    final countRect = tester.getRect(find.byKey(const Key('todoCount')));
    expect((dateRect.center.dx - panelRect.center.dx).abs(), lessThan(0.5));
    expect(toggleRect.top, greaterThan(dateRect.bottom));
    expect(find.byKey(const Key('scheduleScrollbar')), findsOneWidget);
    expect(
      tester
          .widget<Scrollbar>(find.byKey(const Key('scheduleScrollbar')))
          .thumbVisibility,
      isTrue,
    );

    await tester.drag(
      find.byKey(const Key('scheduleScrollView')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const Key('dateTitle'))), dateRect);
    expect(tester.getRect(find.byKey(const Key('todoCount'))), countRect);
    expect(
      tester.getRect(find.byKey(const Key('clockFormatToggle'))),
      toggleRect,
    );
  });

  testWidgets('완료 일정은 할 일 개수에서 제외하고 흐리게 표시한다', (tester) async {
    await tester.pumpWidget(
      SkeChatApp(repository: FakeTodoRepository(includeCompleted: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('완료된 일 1개'), findsOneWidget);
    expect(find.text('할 일 1개'), findsOneWidget);
    final completedOpacity = tester.widget<Opacity>(
      find.byKey(const Key('completedSchedule-2')),
    );
    expect(completedOpacity.opacity, 0.48);
    final completedCheckbox = tester.widget<Checkbox>(
      find.byKey(const Key('scheduleCheckbox-2')),
    );
    expect(completedCheckbox.value, isTrue);
    expect(completedCheckbox.onChanged, isNotNull);
    expect(
      tester.getTopLeft(find.text('가볍게 걷기')).dy,
      lessThan(tester.getTopLeft(find.text('아침 스트레칭')).dy),
    );

    await tester.tap(find.byKey(const Key('scheduleCheckbox-2')));
    await tester.pumpAndSettle();
    expect(find.text('할 일 2개'), findsOneWidget);
    expect(find.text('완료된 일 1개'), findsNothing);
    expect(find.byKey(const Key('completedSchedule-2')), findsNothing);
    expect(
      tester
          .widget<Checkbox>(find.byKey(const Key('scheduleCheckbox-2')))
          .value,
      isFalse,
    );

    await tester.tap(find.byKey(const Key('scheduleCheckbox-1')));
    await tester.pumpAndSettle();
    expect(find.text('할 일 1개'), findsOneWidget);
    expect(find.text('완료된 일 1개'), findsOneWidget);
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
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('chatInput')))
          .controller!
          .text,
      isEmpty,
    );
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

  testWidgets('혼합 CREATE UPDATE DELETE를 항목별 선택 후 한 번에 적용한다', (tester) async {
    final updateBefore = scheduleJson(
      description: '주간 회의',
      eta: '2026-08-04T10:00:00+09:00',
    );
    updateBefore['id'] = 3;
    final deleteBefore = scheduleJson(
      description: '저녁 운동',
      eta: '2026-08-04T19:00:00+09:00',
    );
    deleteBefore['id'] = 4;
    final result = ChatResult.fromJson({
      'message': '3개의 작업을 확인하세요.',
      'preview': {
        'operation_id': 'mixed-op',
        'action': 'mixed',
        'pipeline_revision': 42,
        'before_values': <String, dynamic>{},
        'proposed_values': <String, dynamic>{},
        'items': [
          {
            'item_id': 'item-create',
            'action': 'create',
            'schedule_id': null,
            'before_values': <String, dynamic>{},
            'proposed_values': {
              'eta': '2026-08-04T13:30:00+09:00',
              'description': '치과',
              'alarm_minutes_before': 20,
            },
            'selected': true,
          },
          {
            'item_id': 'item-update',
            'action': 'update',
            'schedule_id': 3,
            'before_values': updateBefore,
            'proposed_values': {'description': '월간 회의'},
            'selected': true,
          },
          {
            'item_id': 'item-delete',
            'action': 'delete',
            'schedule_id': 4,
            'before_values': deleteBefore,
            'proposed_values': <String, dynamic>{},
            'selected': true,
          },
        ],
      },
    });
    final repository = FakeTodoRepository(chatResult: result);
    await tester.pumpWidget(SkeChatApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('chatInput')),
      '치과를 만들고 회의를 수정하고 운동을 삭제해줘',
    );
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('batchPreviewCards')), findsOneWidget);
    expect(find.byKey(const Key('batchAction-create')), findsOneWidget);
    expect(find.byKey(const Key('batchAction-update')), findsOneWidget);
    expect(find.byKey(const Key('batchAction-delete')), findsOneWidget);
    expect(find.text('치과'), findsOneWidget);
    expect(find.text('월간 회의'), findsOneWidget);
    expect(find.text('저녁 운동'), findsOneWidget);

    final deleteCheckbox = find.byKey(
      const Key('batchPreviewCheckbox-item-delete'),
    );
    await tester.ensureVisible(deleteCheckbox);
    await tester.pump();
    await tester.tap(deleteCheckbox);
    await tester.pump();
    final confirmButton = find.byKey(const Key('applySelectedPreviewItems'));
    await tester.ensureVisible(confirmButton);
    await tester.pump();
    await tester.tap(confirmButton);
    await tester.pump(const Duration(milliseconds: 500));

    expect(repository.selectedPreviewItemIds, ['item-create', 'item-update']);
    expect(repository.sentMessages.last, 'YES');
    expect(find.byKey(const Key('batchPreviewCards')), findsNothing);
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
    await tester.testTextInput.receiveAction(TextInputAction.done);
    tester.testTextInput.hide();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('수정된 책 읽기'), findsOneWidget);
    expect(repository.lastPreviewRevision, {'description': '수정된 책 읽기'});

    Future<void> finishSheetAnimation() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    await tester.tap(find.byKey(const Key('createPreview-date')));
    await finishSheetAnimation();
    expect(find.byKey(const Key('recurrenceMode')), findsOneWidget);
    expect(find.text('한 번만'), findsWidgets);
    final editorRect = tester.getRect(
      find.byKey(const Key('scheduleEditorSheet')),
    );
    expect(editorRect.bottom, lessThanOrEqualTo(600), reason: '$editorRect');
    await tester.tap(find.byKey(const Key('scheduleEditorCancel')));
    await finishSheetAnimation();

    await tester.tap(find.byKey(const Key('createPreview-time')));
    await finishSheetAnimation();
    expect(find.byKey(const Key('timeHourWheel')), findsOneWidget);
    expect(find.byKey(const Key('timeMinuteWheel')), findsOneWidget);
    expect(find.byKey(const Key('timeQuickNow')), findsOneWidget);
    await tester.tap(find.byKey(const Key('scheduleEditorCancel')));
    await finishSheetAnimation();

    await tester.tap(find.byKey(const Key('createPreview-alarm')));
    await finishSheetAnimation();
    expect(find.byKey(const Key('alarmMinuteSlider')), findsOneWidget);
    expect(find.byKey(const Key('alarmPreset-10')), findsOneWidget);
    await tester.tap(find.byKey(const Key('scheduleEditorCancel')));
    await finishSheetAnimation();

    await tester.tap(find.byKey(const Key('cancelPreviewButton')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('createPreviewCard')), findsNothing);
    expect(repository.previewCancelled, isTrue);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('chatInput')))
          .controller!
          .text,
      isEmpty,
    );
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
    expect(repository.previewCancelled, isFalse);
    expect(
      repository.sentPipelineRevisions[1],
      greaterThan(repository.sentPipelineRevisions[0]),
    );
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

  testWidgets('채팅 응답 시간 초과는 두 번 재시도한 뒤 성공 결과를 표시한다', (tester) async {
    final repository = FakeTodoRepository(
      previewFromMessage: true,
      timeoutCallNumbers: const {1, 2},
    );
    await tester.pumpWidget(SkeChatApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('chatInput')), '재시도 일정');
    await tester.pump(const Duration(milliseconds: 501));
    await tester.pump(const Duration(milliseconds: 401));
    await tester.pump(const Duration(milliseconds: 801));
    await tester.pump();

    expect(repository.sentMessages, ['재시도 일정', '재시도 일정', '재시도 일정']);
    expect(repository.sentPipelineRevisions.toSet(), hasLength(1));
    expect(find.byKey(const Key('createPreviewCard')), findsOneWidget);
    expect(find.byKey(const Key('chatErrorResponse')), findsNothing);
  });

  testWidgets('스와이프 삭제는 REST 저장소를 직접 호출하고 복구 목록을 표시한다', (tester) async {
    final repository = FakeTodoRepository();
    await tester.pumpWidget(SkeChatApp(repository: repository));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('chatInput')))
          .decoration
          ?.hintText,
      'Skechat으로 일정을 관리해보세요!',
    );

    await tester.drag(find.text('가볍게 걷기'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(repository.directlyDeletedIds, [1]);
    expect(find.text('가볍게 걷기'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('chatInput')))
          .decoration
          ?.hintText,
      '삭제된 일정을 복구하시려면 복구를 입력하세요',
    );
    await tester.pump(const Duration(minutes: 4, seconds: 59));
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('chatInput')))
          .decoration
          ?.hintText,
      '삭제된 일정을 복구하시려면 복구를 입력하세요',
    );
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('chatInput')))
          .decoration
          ?.hintText,
      'Skechat으로 일정을 관리해보세요!',
    );

    await tester.enterText(find.byKey(const Key('chatInput')), '복구');
    await tester.pump(const Duration(milliseconds: 501));
    await tester.pump();
    expect(find.byKey(const Key('recoveryPanel')), findsOneWidget);
    expect(repository.sentMessages, isEmpty);
    expect(find.byKey(const Key('recoverySchedule-100')), findsOneWidget);
    expect(find.byKey(const Key('recoverySchedule-102')), findsOneWidget);

    await tester.tap(find.byKey(const Key('restoreSchedule-100')));
    await tester.pumpAndSettle();
    expect(repository.restoredIds, [100]);
  });

  testWidgets('재분석 중 기존 미리보기에 로딩을 표시하고 통신 실패를 알린다', (tester) async {
    final repository = FakeTodoRepository(
      previewFromMessage: true,
      delayedCallNumber: 2,
      chatDelay: const Duration(seconds: 2),
      chatError: const ApiTimeoutException(),
      timeoutCallNumbers: const {3, 4},
    );
    await tester.pumpWidget(SkeChatApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('chatInput')), '첫 일정');
    await tester.pump(const Duration(milliseconds: 501));
    await tester.pump();
    expect(find.byKey(const Key('createPreviewCard')), findsOneWidget);
    final sentDate = repository.sentContextDates.single;
    final loadedDate = repository._lastDate!;
    expect(
      DateTime(sentDate.year, sentDate.month, sentDate.day),
      DateTime(loadedDate.year, loadedDate.month, loadedDate.day),
    );

    await tester.enterText(find.byKey(const Key('chatInput')), '변경된 일정');
    await tester.pump(const Duration(milliseconds: 501));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('previewLoadingIndicator')), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(find.byKey(const Key('previewLoadingIndicator')), findsNothing);
    expect(find.byKey(const Key('chatErrorResponse')), findsOneWidget);
    expect(find.textContaining('응답 시간이 초과'), findsOneWidget);
    expect(
      repository.sentMessages.where((message) => message == '변경된 일정'),
      hasLength(3),
    );
  });

  testWidgets('중앙 서버 연결 실패 팝업은 닫기 없이 항상 표시된다', (tester) async {
    await tester.pumpWidget(
      SkeChatApp(
        repository: FakeTodoRepository(
          syncError: const ApiException('central server unavailable'),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('centralServerOfflinePopup')), findsNothing);
    await tester.pump();

    expect(find.byKey(const Key('centralServerOfflinePopup')), findsOneWidget);
    expect(find.text('중앙 서버에 연결할 수 없습니다'), findsOneWidget);
    expect(find.textContaining('이 기기에 안전하게 저장'), findsOneWidget);
    expect(find.byType(CloseButton), findsNothing);
  });
}
