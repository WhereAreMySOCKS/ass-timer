import 'package:ass_timer_flutter/core/theme/app_theme.dart';
import 'package:ass_timer_flutter/features/onboarding/circular_interval_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('interval picker exposes a readable value', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Center(
            child: CircularIntervalPicker(
              seconds: 2400,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('40 分钟'), findsOneWidget);
    expect(
      tester.getSize(find.byType(CircularIntervalPicker)),
      const Size.square(190),
    );
    final semantics = tester.getSemantics(find.byType(CircularIntervalPicker));
    expect(semantics.label, contains('提醒间隔'));
    expect('${semantics.label}${semantics.value}', contains('40 分钟'));
  });

  testWidgets('keyboard adjustment commits once through onChangeEnd',
      (tester) async {
    var seconds = 2400;
    final committed = <int>[];
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Center(
              child: CircularIntervalPicker(
                seconds: seconds,
                onChanged: (value) => setState(() => seconds = value),
                onChangeEnd: committed.add,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(CircularIntervalPicker));
    committed.clear();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(seconds, 2405);
    expect(committed, <int>[2405]);
  });
}
