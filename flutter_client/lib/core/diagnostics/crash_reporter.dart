import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CrashReporter {
  CrashReporter._();

  static final CrashReporter instance = CrashReporter._();

  Directory? _logsDirectory;
  File? _logFile;

  String? get logsDirectoryPath => _logsDirectory?.path;

  Future<void> initialize() async {
    try {
      await _initializeAtRoot(await _diagnosticsRoot());
    } on Object catch (error) {
      debugPrint('Unable to initialize diagnostics: $error');
    }
  }

  @visibleForTesting
  Future<void> initializeForTesting(Directory root) => _initializeAtRoot(root);

  Future<void> _initializeAtRoot(Directory root) async {
    try {
      final logs = Directory(p.join(root.path, 'logs'));
      final crashes = Directory(p.join(root.path, 'crashes'));
      await logs.create(recursive: true);
      await crashes.create(recursive: true);
      _logsDirectory = logs;
      _logFile = File(
        p.join(
          logs.path,
          'ass-timer-$pid-${DateTime.now().millisecondsSinceEpoch}.log',
        ),
      );
      await _append('INFO', 'startup', 'Diagnostics initialized');
    } on Object catch (error) {
      debugPrint('Unable to initialize diagnostics: $error');
    }
  }

  Future<void> record(
    Object error,
    StackTrace stack, {
    String context = 'unhandled',
    bool fatal = false,
  }) =>
      _append(
        fatal ? 'FATAL' : 'ERROR',
        context,
        '$error\n$stack',
      );

  void recordSync(
    Object error,
    StackTrace stack, {
    String context = 'unhandled',
    bool fatal = false,
  }) {
    final entry = _formatEntry(
      fatal ? 'FATAL' : 'ERROR',
      context,
      '$error\n$stack',
    );
    debugPrint(entry);
    try {
      _logFile?.writeAsStringSync(entry, mode: FileMode.append, flush: true);
    } on Object {
      // Diagnostics must never become another startup failure.
    }
  }

  Future<bool> openLogsDirectory() async {
    final directory = _logsDirectory;
    if (directory == null) return false;
    try {
      final result = Platform.isWindows
          ? await Process.run('explorer.exe', <String>[directory.path])
          : await Process.run('open', <String>[directory.path]);
      return result.exitCode == 0;
    } on Object catch (error, stack) {
      unawaited(record(error, stack, context: 'open_logs_directory'));
      return false;
    }
  }

  Future<Directory> _diagnosticsRoot() async {
    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData != null && localAppData.isNotEmpty) {
        return Directory(p.join(localAppData, 'AssTimer'));
      }
    }
    final applicationSupport = await getApplicationSupportDirectory();
    return Directory(p.join(applicationSupport.path, 'AssTimer'));
  }

  Future<void> _append(String level, String context, String message) async {
    final entry = _formatEntry(level, context, message);
    debugPrint(entry);
    try {
      await _logFile?.writeAsString(entry, mode: FileMode.append, flush: true);
    } on Object {
      // Best-effort logging only.
    }
  }

  String _formatEntry(String level, String context, String message) =>
      '${DateTime.now().toUtc().toIso8601String()} '
      '[$level] [$context] $message\n';
}
