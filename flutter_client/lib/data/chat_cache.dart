import 'dart:convert';
import 'dart:io';

import 'package:ass_timer_flutter/data/api_models.dart';
import 'package:ass_timer_flutter/data/app_store.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

class ChatCache {
  ChatCache(AppStore store) : this._(store);

  ChatCache.forRoot(Future<Directory> Function() rootProvider)
      : this._(null, rootProvider: rootProvider);

  ChatCache._(this._store, {Future<Directory> Function()? rootProvider})
      : _rootProvider = rootProvider;

  final AppStore? _store;
  final Future<Directory> Function()? _rootProvider;

  Future<List<ChatMessage>> load(String groupId) async {
    final file = await _file(groupId);
    if (!file.existsSync()) return <ChatMessage>[];
    try {
      final decoded = jsonDecode(await file.readAsString()) as List<dynamic>;
      final messages = decoded
          .whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList();
      messages.sort(ChatMessage.chronologicalOrder);
      return messages;
    } on Object {
      return <ChatMessage>[];
    }
  }

  Future<List<ChatMessage>> merge(
    String groupId,
    Iterable<ChatMessage> incoming,
  ) async {
    final byId = <String, ChatMessage>{
      for (final message in await load(groupId)) message.messageId: message,
      for (final message in incoming) message.messageId: message,
    };
    final messages = byId.values.toList()..sort(ChatMessage.chronologicalOrder);
    final recent = messages.length <= 100
        ? messages
        : messages.sublist(messages.length - 100);
    final file = await _file(groupId);
    await file.writeAsString(
      jsonEncode(recent.map((message) => message.toJson()).toList()),
      flush: true,
    );
    return recent;
  }

  Future<File> _file(String groupId) async {
    final root = await (_rootProvider?.call() ?? _store!.appSupportRoot());
    final directory = Directory(p.join(root.path, 'chat'));
    if (!directory.existsSync()) await directory.create(recursive: true);
    final digest = sha256.convert(utf8.encode(groupId)).toString();
    return File(p.join(directory.path, '$digest.json'));
  }
}
