import 'package:ass_timer_flutter/domain/app_models.dart';
import 'package:ass_timer_flutter/domain/bubble_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reminder is unique and sorted before social bubbles', () {
    List<BubbleItem> latest = <BubbleItem>[];
    final queue = BubbleQueue(onChanged: (items) => latest = items);

    queue
      ..add(BubbleKind.groupEvent, senderNickname: '鹿友')
      ..add(BubbleKind.reminder)
      ..add(BubbleKind.reminder);

    expect(latest, hasLength(2));
    expect(latest.first.kind, BubbleKind.reminder);
    queue.dispose();
  });

  testWidgets('feedback follows a reminder and dismisses quickly',
      (tester) async {
    List<BubbleItem> latest = <BubbleItem>[];
    final queue = BubbleQueue(onChanged: (items) => latest = items);

    queue
      ..add(BubbleKind.groupEvent, senderNickname: '鹿友')
      ..add(BubbleKind.reminder)
      ..add(
        BubbleKind.feedback,
        message: '行，记你一次。',
        feedbackTone: BubbleFeedbackTone.success,
      )
      ..removeKind(BubbleKind.reminder);

    expect(latest.first.kind, BubbleKind.feedback);
    expect(latest.first.feedbackTone, BubbleFeedbackTone.success);
    await tester.pump(const Duration(milliseconds: 1401));
    expect(latest.any((item) => item.kind == BubbleKind.feedback), isFalse);
    expect(latest.single.kind, BubbleKind.groupEvent);
    queue.dispose();
  });
}
