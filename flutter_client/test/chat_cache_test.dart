import 'dart:io';

import 'package:ass_timer_flutter/data/api_models.dart';
import 'package:ass_timer_flutter/data/chat_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporary;
  late ChatCache cache;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('ass-timer-chat-test-');
    cache = ChatCache.forRoot(() async => temporary);
  });

  tearDown(() async {
    if (temporary.existsSync()) await temporary.delete(recursive: true);
  });

  test('deduplicates by message id and keeps the latest value', () async {
    await cache.merge('group-a', <ChatMessage>[
      _message(1, 'same-id', 'old'),
    ]);

    final result = await cache.merge('group-a', <ChatMessage>[
      _message(2, 'same-id', 'new'),
    ]);

    expect(result, hasLength(1));
    expect(result.single.content, 'new');
    expect((await cache.load('group-a')).single.sequence, 2);
  });

  test('keeps only the newest 100 messages in chronological order', () async {
    final result = await cache.merge(
      'group-a',
      List<ChatMessage>.generate(
        105,
        (index) => _message(index, 'message-$index', '$index'),
      ).reversed,
    );

    expect(result, hasLength(100));
    expect(result.first.sequence, 5);
    expect(result.last.sequence, 104);
  });
}

ChatMessage _message(int sequence, String id, String content) => ChatMessage(
      sequence: sequence,
      messageId: id,
      groupId: 'group-a',
      userId: 'user-a',
      nickname: 'Paul',
      petEmoji: '🦌',
      avatarUrl: '',
      content: content,
      createdAt: DateTime.utc(2026, 1, 1).add(Duration(seconds: sequence)),
    );
