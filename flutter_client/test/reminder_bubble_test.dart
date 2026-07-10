import 'package:ass_timer_flutter/core/theme/app_theme.dart';
import 'package:ass_timer_flutter/core/window/bubble_layout.dart';
import 'package:ass_timer_flutter/features/bubble/reminder_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('normal reminder fits its native bubble window', (tester) async {
    await _pumpBubble(
      tester,
      obedient: false,
      windowSize: normalBubbleContentSize,
    );

    expect(
      tester.getSize(find.byType(ReminderBubbleContent)),
      normalBubbleContentSize,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('该提肛了！'), findsOneWidget);
    expect(find.text('收到'), findsOneWidget);
    expect(find.text('等会'), findsOneWidget);
    _expectActionButtonsSameSize(tester);
  });

  testWidgets('obedient reminder fits its compact native bubble window',
      (tester) async {
    await _pumpBubble(
      tester,
      obedient: true,
      windowSize: obedientBubbleContentSize,
    );

    expect(
      tester.getSize(find.byType(ReminderBubbleContent)),
      obedientBubbleContentSize,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('该放松了'), findsOneWidget);
    expect(find.text('缓一口气'), findsOneWidget);
    expect(find.text('收到'), findsOneWidget);
    expect(find.text('等会'), findsOneWidget);
    _expectActionButtonsSameSize(tester);
  });

  testWidgets('obedient reminder keeps title and actions visually grouped',
      (tester) async {
    await _pumpBubble(
      tester,
      obedient: true,
      windowSize: obedientBubbleContentSize,
    );

    final titleBottom = tester.getBottomLeft(find.text('该放松了')).dy;
    final actionTop = tester
        .getTopLeft(find.byKey(const ValueKey<String>('reminder-actions')))
        .dy;
    final actionBottom = tester
        .getBottomLeft(find.byKey(const ValueKey<String>('reminder-actions')))
        .dy;

    expect(actionTop - titleBottom, lessThanOrEqualTo(32));
    expect(
      obedientBubbleContentSize.height - actionBottom,
      lessThanOrEqualTo(18),
    );
  });
}

Future<void> _pumpBubble(
  WidgetTester tester, {
  required bool obedient,
  required Size windowSize,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = windowSize;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Material(
        type: MaterialType.transparency,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ReminderBubbleContent(
            obedient: obedient,
            reminderTitle: obedient ? '该放松了！' : '该提肛了！',
            exerciseName: obedient ? '放松' : '提肛',
            onComplete: _noop,
            onSkip: _noop,
          ),
        ),
      ),
    ),
  );
}

void _noop() {}

void _expectActionButtonsSameSize(WidgetTester tester) {
  expect(
    tester
        .getSize(find.byKey(const ValueKey<String>('reminder-primary-action'))),
    tester.getSize(
      find.byKey(const ValueKey<String>('reminder-secondary-action')),
    ),
  );
}
