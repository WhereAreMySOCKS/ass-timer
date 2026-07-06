import 'dart:io';

import 'package:ass_timer_flutter/core/diagnostics/crash_reporter.dart';
import 'package:ass_timer_flutter/core/window/desktop_host.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tray failure is reported and enables taskbar fallback', () async {
    var reported = false;
    var fallbackShown = false;

    final available = await initializeTrayWithFallback(
      initialize: () => throw StateError('tray unavailable'),
      report: (error, stack) async => reported = true,
      showTaskbarFallback: () async => fallbackShown = true,
    );

    expect(available, isFalse);
    expect(reported, isTrue);
    expect(fallbackShown, isTrue);
  });

  test('crash reporter writes errors to its log directory', () async {
    final root = await Directory.systemTemp.createTemp('ass-timer-diagnostics');
    addTearDown(() => root.delete(recursive: true));
    await CrashReporter.instance.initializeForTesting(root);

    await CrashReporter.instance.record(
      StateError('test failure'),
      StackTrace.current,
      context: 'test',
    );

    final logs = Directory('${root.path}${Platform.pathSeparator}logs');
    final files = await logs.list().where((entry) => entry is File).toList();
    expect(files, hasLength(1));
    expect(
        await File(files.single.path).readAsString(), contains('test failure'));
  });
}
