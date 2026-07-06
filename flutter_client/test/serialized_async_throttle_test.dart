import 'dart:async';

import 'package:ass_timer_flutter/core/window/serialized_async_throttle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('coalesces requests and never overlaps asynchronous work', () async {
    final throttle = SerializedAsyncThrottle(
      const Duration(milliseconds: 10),
    );
    final firstCompleter = Completer<void>();
    var active = 0;
    var maximumActive = 0;
    var runs = 0;

    Future<void> action() async {
      runs += 1;
      active += 1;
      maximumActive = active > maximumActive ? active : maximumActive;
      if (runs == 1) await firstCompleter.future;
      active -= 1;
    }

    throttle.schedule(action, immediate: true);
    throttle.schedule(action);
    throttle.schedule(action);
    await Future<void>.delayed(Duration.zero);
    expect(runs, 1);

    firstCompleter.complete();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(runs, 2);
    expect(maximumActive, 1);
    throttle.dispose();
  });
}
