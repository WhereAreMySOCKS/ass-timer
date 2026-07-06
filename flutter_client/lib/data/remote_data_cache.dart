import 'dart:convert';
import 'dart:io';

import 'package:ass_timer_flutter/data/api_models.dart';
import 'package:ass_timer_flutter/data/app_store.dart';
import 'package:path/path.dart' as p;

class RemoteDataCache {
  RemoteDataCache(AppStore store) : this.forRoot(store.appSupportRoot);

  RemoteDataCache.forRoot(this._rootProvider);

  final Future<Directory> Function() _rootProvider;

  Future<List<GroupInfo>> loadGroups(String userId) =>
      _loadList('groups-${_safeName(userId)}.json', GroupInfo.fromJson);

  Future<void> saveGroups(String userId, List<GroupInfo> groups) => _saveList(
        'groups-${_safeName(userId)}.json',
        groups.map((group) => group.toJson()).toList(growable: false),
      );

  Future<List<LeaderboardEntry>> loadLeaderboard(String groupId) => _loadList(
        'leaderboard-${_safeName(groupId)}.json',
        LeaderboardEntry.fromJson,
      );

  Future<void> saveLeaderboard(
    String groupId,
    List<LeaderboardEntry> entries,
  ) =>
      _saveList(
        'leaderboard-${_safeName(groupId)}.json',
        entries.map((entry) => entry.toJson()).toList(growable: false),
      );

  Future<List<T>> _loadList<T>(
    String fileName,
    T Function(Map<String, dynamic>) decode,
  ) async {
    try {
      final file = await _file(fileName);
      if (!file.existsSync()) return <T>[];
      final raw = jsonDecode(await file.readAsString());
      if (raw is! List<dynamic>) return <T>[];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(decode)
          .toList(growable: false);
    } on Object {
      return <T>[];
    }
  }

  Future<void> _saveList(
    String fileName,
    List<Map<String, dynamic>> value,
  ) async {
    final file = await _file(fileName);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(value), flush: true);
    if (file.existsSync()) await file.delete();
    await temporary.rename(file.path);
  }

  Future<File> _file(String name) async {
    final root = await _rootProvider();
    final directory = Directory(p.join(root.path, 'remote-cache'));
    if (!directory.existsSync()) await directory.create(recursive: true);
    return File(p.join(directory.path, name));
  }

  static String _safeName(String value) =>
      value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
}
