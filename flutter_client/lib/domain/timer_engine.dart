import 'dart:async';

import 'package:ass_timer_flutter/domain/app_models.dart';

typedef Clock = DateTime Function();

class TimerEngine {
  TimerEngine({
    required this.onChanged,
    required this.onFire,
    Clock? clock,
  }) : _clock = clock ?? DateTime.now;

  final void Function(TimerPhase phase, DateTime? nextReminderAt) onChanged;
  final void Function() onFire;
  final Clock _clock;

  Timer? _ticker;
  TimerPhase phase = TimerPhase.idle;
  DateTime? nextReminderAt;

  void start({
    required int intervalSeconds,
    DateTime? restoredReminderAt,
  }) {
    stopTicker();
    nextReminderAt = restoredReminderAt ??
        _clock().add(Duration(seconds: normalizeInterval(intervalSeconds)));
    if (!_clock().isBefore(nextReminderAt!)) {
      _fire();
      return;
    }
    phase = TimerPhase.running;
    onChanged(phase, nextReminderAt);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => checkDue());
  }

  void checkDue() {
    final dueAt = nextReminderAt;
    if (phase == TimerPhase.running &&
        dueAt != null &&
        !_clock().isBefore(dueAt)) {
      _fire();
    }
  }

  void complete({required int intervalSeconds}) {
    if (phase != TimerPhase.reminder) return;
    phase = TimerPhase.confirming;
    onChanged(phase, nextReminderAt);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (phase != TimerPhase.confirming) return;
      reset(intervalSeconds: intervalSeconds);
    });
  }

  void skip({required int intervalSeconds}) {
    if (phase != TimerPhase.reminder) return;
    reset(intervalSeconds: (normalizeInterval(intervalSeconds) / 2).round());
  }

  void reset({required int intervalSeconds}) {
    phase = TimerPhase.reset;
    onChanged(phase, nextReminderAt);
    nextReminderAt = null;
    start(intervalSeconds: intervalSeconds);
  }

  void handleWake({required int intervalSeconds}) {
    final dueAt = nextReminderAt;
    if (dueAt == null) {
      start(intervalSeconds: intervalSeconds);
    } else if (!_clock().isBefore(dueAt)) {
      _fire();
    } else {
      start(intervalSeconds: intervalSeconds, restoredReminderAt: dueAt);
    }
  }

  void stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void dispose() => stopTicker();

  static int normalizeInterval(int seconds) => seconds.clamp(10, 7200);

  void _fire() {
    stopTicker();
    phase = TimerPhase.reminder;
    onChanged(phase, nextReminderAt);
    onFire();
  }
}
