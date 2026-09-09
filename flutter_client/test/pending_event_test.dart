import 'package:ass_timer_flutter/domain/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round-trips a pending event for durable retry', () {
    final event = PendingEvent(
      eventId: 'event-1',
      userId: 'user-1',
      groupIds: const <String>['group-1', 'group-2'],
      occurredAt: DateTime.utc(2026, 9, 9, 2, 30),
    );

    final restored = PendingEvent.fromJson(event.toJson());
    expect(restored.eventId, event.eventId);
    expect(restored.userId, event.userId);
    expect(restored.groupIds, event.groupIds);
    expect(restored.occurredAt, event.occurredAt);
  });
}
