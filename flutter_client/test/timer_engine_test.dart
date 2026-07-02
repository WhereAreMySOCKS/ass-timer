import 'package:ass_timer_flutter/domain/app_models.dart';
import 'package:ass_timer_flutter/domain/timer_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('restores a future absolute reminder', () {
    var now = DateTime(2026, 7, 2, 9);
    TimerPhase? phase;
    DateTime? next;
    var fired = 0;
    final engine = TimerEngine(
      clock: () => now,
      onChanged: (value, reminderAt) {
        phase = value;
        next = reminderAt;
      },
      onFire: () => fired += 1,
    );
    final restored = now.add(const Duration(minutes: 20));

    engine.start(intervalSeconds: 2400, restoredReminderAt: restored);

    expect(phase, TimerPhase.running);
    expect(next, restored);
    expect(fired, 0);
    engine.dispose();
  });

  test('fires exactly once when restored reminder is overdue', () {
    final now = DateTime(2026, 7, 2, 9);
    var fired = 0;
    final engine = TimerEngine(
      clock: () => now,
      onChanged: (_, __) {},
      onFire: () => fired += 1,
    );

    engine.start(
      intervalSeconds: 2400,
      restoredReminderAt: now.subtract(const Duration(minutes: 1)),
    );
    engine.checkDue();

    expect(engine.phase, TimerPhase.reminder);
    expect(fired, 1);
    engine.dispose();
  });

  test('skip schedules the next reminder at half interval', () {
    final now = DateTime(2026, 7, 2, 9);
    final engine = TimerEngine(
      clock: () => now,
      onChanged: (_, __) {},
      onFire: () {},
    )
      ..start(
        intervalSeconds: 2400,
        restoredReminderAt: now.subtract(const Duration(seconds: 1)),
      )
      ..skip(intervalSeconds: 2400);

    expect(engine.phase, TimerPhase.running);
    expect(engine.nextReminderAt, now.add(const Duration(minutes: 20)));
    engine.dispose();
  });
}
