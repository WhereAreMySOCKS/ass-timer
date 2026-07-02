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
}
