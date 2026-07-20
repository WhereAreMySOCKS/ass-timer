import 'package:ass_timer_flutter/core/theme/app_theme.dart';
import 'package:ass_timer_flutter/core/widgets/speech_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final tail in SpeechBubbleTail.values) {
    testWidgets('${tail.name} tail fits without clipping errors',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Center(
              child: SpeechBubble(
                tail: tail,
                width: tail == SpeechBubbleTail.bottom ? 220 : 210,
                height: tail == SpeechBubbleTail.bottom ? 90 : 100,
                semanticLabel: '测试气泡',
                child: const Text('网断了，本地记录还在。'),
              ),
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(SpeechBubble));
      expect(size, const Size(220, 100));
      expect(tester.takeException(), isNull);
      expect(
        tester.getSemantics(find.byType(SpeechBubble)).label,
        contains('测试气泡'),
      );
    });
  }
}
