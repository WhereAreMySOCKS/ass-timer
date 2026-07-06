import 'dart:io';

import 'package:ass_timer_flutter/data/api_models.dart';
import 'package:ass_timer_flutter/data/remote_data_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporary;
  late RemoteDataCache cache;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('ass-timer-remote-test-');
    cache = RemoteDataCache.forRoot(() async => temporary);
  });

  tearDown(() async {
    if (temporary.existsSync()) await temporary.delete(recursive: true);
  });

  test('persists group details for offline startup', () async {
    const groups = <GroupInfo>[
      GroupInfo(
        groupId: 'group-a',
        name: 'Alpha',
        inviteCode: 'ABC123',
        members: <GroupMember>[],
      ),
    ];

    await cache.saveGroups('user-a', groups);

    final restored = await cache.loadGroups('user-a');
    expect(restored.single.name, 'Alpha');
    expect(restored.single.inviteCode, 'ABC123');
  });

  test('persists leaderboard entries per group', () async {
    const entries = <LeaderboardEntry>[
      LeaderboardEntry(
        rank: 1,
        userId: 'user-a',
        nickname: 'Paul',
        petEmoji: '🦌',
        avatarUrl: '/uploads/avatars/a.png',
        count: 8,
      ),
    ];

    await cache.saveLeaderboard('group-a', entries);

    final restored = await cache.loadLeaderboard('group-a');
    expect(restored.single.count, 8);
    expect(restored.single.avatarUrl, '/uploads/avatars/a.png');
  });
}
