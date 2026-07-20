import 'dart:async';

import 'package:ass_timer_flutter/core/theme/app_theme.dart';
import 'package:ass_timer_flutter/core/widgets/app_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('danger confirmation cancels with Escape and focuses cancel',
      (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () {
                unawaited(
                  showAppConfirmDialog(
                    context,
                    title: '清除本地数据？',
                    message: '清除后无法恢复。',
                    confirmLabel: '清除数据',
                    destructive: true,
                  ).then((value) => result = value),
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    final cancel = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '取消'),
    );
    expect(cancel.autofocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('清除本地数据？'), findsNothing);
    expect(result, isFalse);
  });
}
