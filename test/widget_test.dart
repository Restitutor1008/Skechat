import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skechat/main.dart';

void main() {
  testWidgets('main schedule screen renders and changes clock format', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('2026년'), findsOneWidget);
    expect(find.text('7월 16일'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('14:00'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);

    await tester.tap(find.byKey(const Key('12HourButton')));
    await tester.pump();

    expect(find.text('오전'), findsOneWidget);
    expect(find.text('오후'), findsOneWidget);
    expect(find.text('02:00'), findsOneWidget);
  });

  testWidgets('date navigation updates the visible date', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.byKey(const Key('nextDateButton')));
    await tester.pump();

    expect(find.text('7월 17일'), findsOneWidget);
  });

  testWidgets('layout fits a narrow phone viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());
    expect(tester.takeException(), isNull);
    expect(find.text('헬스장'), findsOneWidget);
    expect(find.text('치과 예약'), findsOneWidget);
  });
}
