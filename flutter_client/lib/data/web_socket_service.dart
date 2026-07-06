import 'dart:async';
import 'dart:convert';

import 'package:ass_timer_flutter/data/api_models.dart';
import 'package:ass_timer_flutter/domain/app_models.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

const String defaultWsBaseUrl = String.fromEnvironment(
  'ASS_TIMER_WS_URL',
  defaultValue: 'wss://api.guiji.online/ass-timer',
);

sealed class ServerEvent {
  const ServerEvent();
}

class GroupCompletionEvent extends ServerEvent {
  const GroupCompletionEvent({
    required this.groupId,
    required this.nickname,
    required this.petEmoji,
    this.avatarUrl,
  });

  final String groupId;
  final String nickname;
  final String petEmoji;
  final String? avatarUrl;
}

class ChatServerEvent extends ServerEvent {
  const ChatServerEvent(this.message);

  final ChatMessage message;
}

ServerEvent? decodeServerEvent(String raw) {
  final dynamic decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    throw const FormatException('WebSocket 消息不是有效 JSON');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('WebSocket 消息必须是对象');
  }
  final type = decoded['type'];
  if (type is! String) {
    throw const FormatException('WebSocket 消息缺少 type');
  }
  if (type != 'group_event' && type != 'chat_message') return null;
  final data = decoded['data'];
  if (data is! Map<String, dynamic>) {
    throw const FormatException('WebSocket 消息缺少 data');
  }
  try {
    if (type == 'group_event') {
      final nickname = data['nickname'];
      final groupId = decoded['group_id'];
      if (nickname is! String || groupId is! String) {
        throw const FormatException('群组事件字段无效');
      }
      final petEmoji = data['pet_emoji'];
      final avatarUrl = data['avatar_url'];
      return GroupCompletionEvent(
        groupId: groupId,
        nickname: nickname,
        petEmoji: petEmoji is String ? petEmoji : '🦌',
        avatarUrl: avatarUrl is String ? avatarUrl : null,
      );
    }
    return ChatServerEvent(ChatMessage.fromJson(data));
  } on FormatException {
    rethrow;
  } on Object catch (error) {
    throw FormatException('WebSocket 消息字段无效: $error');
  }
}

class WebSocketService {
  WebSocketService({
    required this.onEvent,
    this.onConnectionStateChanged,
    this.onMalformedMessage,
    this.baseUrl = defaultWsBaseUrl,
  });

  final void Function(ServerEvent event) onEvent;
  final void Function(BackendConnectionState state)? onConnectionStateChanged;
  final void Function(Object error, StackTrace stack)? onMalformedMessage;
  final String baseUrl;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  String? _userId;
  int _attempt = 0;
  bool _shouldReconnect = false;

  Future<void> connect(String userId) async {
    if (_userId == userId && _channel != null) return;
    await disconnect();
    _userId = userId;
    _shouldReconnect = true;
    _attempt = 0;
    onConnectionStateChanged?.call(BackendConnectionState.connecting);
    _open();
  }

  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _subscription = null;
    _userId = null;
    onConnectionStateChanged?.call(BackendConnectionState.disconnected);
  }

  void _open() {
    final userId = _userId;
    if (!_shouldReconnect || userId == null || _channel != null) return;
    try {
      final channel =
          WebSocketChannel.connect(Uri.parse('$baseUrl/ws/$userId'));
      _channel = channel;
      unawaited(
        channel.ready.then((_) {
          if (identical(_channel, channel)) {
            _attempt = 0;
            onConnectionStateChanged?.call(BackendConnectionState.connected);
          }
        }).catchError((Object _) {
          if (identical(_channel, channel)) _handleDisconnect();
        }),
      );
      _subscription = channel.stream.listen(
        _handleMessage,
        onDone: _handleDisconnect,
        onError: (_) => _handleDisconnect(),
        cancelOnError: true,
      );
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _channel?.sink.add(jsonEncode(<String, String>{'type': 'ping'}));
      });
    } on Object {
      _handleDisconnect();
    }
  }

  void _handleMessage(dynamic raw) {
    if (raw is! String) return;
    try {
      final event = decodeServerEvent(raw);
      if (event != null) onEvent(event);
      _attempt = 0;
    } on Object catch (error, stack) {
      onMalformedMessage?.call(error, stack);
    }
  }

  void _handleDisconnect() {
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    _pingTimer?.cancel();
    onConnectionStateChanged?.call(BackendConnectionState.disconnected);
    if (!_shouldReconnect) return;
    final seconds = (1 << _attempt.clamp(0, 5)).clamp(1, 30);
    _attempt = (_attempt + 1).clamp(0, 10);
    _reconnectTimer?.cancel();
    onConnectionStateChanged?.call(BackendConnectionState.connecting);
    _reconnectTimer = Timer(Duration(seconds: seconds), _open);
  }
}
