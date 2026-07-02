import 'dart:convert';
import 'dart:io';

import 'package:ass_timer_flutter/domain/app_models.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppStore {
  AppStore({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _configKey = 'ass_timer_flutter_config_v2';
  static const String _nextReminderKey = 'ass_timer_flutter_next_reminder_at';
  static const String _migrationKey = 'ass_timer_flutter_migration_version';
  static const MethodChannel _legacyChannel =
      MethodChannel('ass_timer/legacy_migration');

  final SharedPreferencesAsync _preferences;

  Future<UserConfig> loadConfig() async {
    await migrateLegacyMacStateIfNeeded();
    final encoded = await _preferences.getString(_configKey);
    if (encoded == null || encoded.isEmpty) return const UserConfig();
    try {
      return UserConfig.fromJson(jsonDecode(encoded) as Map<String, dynamic>);
    } on Object {
      return const UserConfig();
    }
  }

  Future<void> saveConfig(UserConfig config) =>
      _preferences.setString(_configKey, config.encode());

  Future<DateTime?> loadNextReminderAt() async {
    final millis = await _preferences.getInt(_nextReminderKey);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> saveNextReminderAt(DateTime? value) async {
    if (value == null) {
      await _preferences.remove(_nextReminderKey);
    } else {
      await _preferences.setInt(_nextReminderKey, value.millisecondsSinceEpoch);
    }
  }

  Future<void> clearLocalState() async {
    await _preferences.remove(_configKey);
    await _preferences.remove(_nextReminderKey);
    // Keep migrationVersion=1. Otherwise the next launch would immediately
    // import the legacy Swift preferences that the user just chose to clear.
    final root = await appSupportRoot();
    for (final name in <String>['chat', 'custom-actions']) {
      final directory = Directory(p.join(root.path, name));
      if (directory.existsSync()) await directory.delete(recursive: true);
    }
  }

  Future<void> migrateLegacyMacStateIfNeeded() async {
    if (!Platform.isMacOS ||
        (await _preferences.getInt(_migrationKey) ?? 0) >= 1) {
      return;
    }

    try {
      final legacy = await _legacyChannel.invokeMapMethod<String, dynamic>(
        'readLegacyState',
      );
      final rawConfig = legacy?['configData'];
      if (rawConfig is Uint8List && rawConfig.isNotEmpty) {
        final configJson = jsonDecode(utf8.decode(rawConfig));
        final config = UserConfig.fromJson(configJson as Map<String, dynamic>);
        await saveConfig(config);
      }

      final nextReminderSeconds = legacy?['nextReminderTimestamp'];
      if (nextReminderSeconds is num && nextReminderSeconds > 0) {
        await saveNextReminderAt(
          DateTime.fromMillisecondsSinceEpoch(
            (nextReminderSeconds * 1000).round(),
          ),
        );
      }
      await _preferences.setInt(_migrationKey, 1);
    } on MissingPluginException {
      // Unit tests and non-GA beta runners do not expose the migration bridge.
    } on PlatformException {
      // Keep migrationVersion unset so a later launch can retry safely.
    } on FormatException {
      // The old data remains untouched and can still be read by the Swift app.
    }
  }

  Future<Directory> appSupportRoot() async {
    final base = await getApplicationSupportDirectory();
    // path_provider appends the bundle identifier on macOS, while the Swift
    // client stored data directly under Application Support/AssTimer.
    final root = Directory(
      Platform.isMacOS
          ? p.join(base.parent.path, 'AssTimer')
          : p.join(base.path, 'AssTimer'),
    );
    if (!root.existsSync()) await root.create(recursive: true);
    return root;
  }

  Future<Directory> customMediaRoot() async {
    final root = await appSupportRoot();
    final media = Directory(p.join(root.path, 'custom-actions'));
    if (!media.existsSync()) await media.create(recursive: true);
    return media;
  }
}
