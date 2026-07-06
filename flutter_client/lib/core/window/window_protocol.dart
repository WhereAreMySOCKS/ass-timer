import 'dart:convert';

import 'package:ass_timer_flutter/domain/app_models.dart';
import 'package:uuid/uuid.dart';

const int windowProtocolVersion = 1;

enum WindowMessageType {
  hello,
  stateSnapshot,
  command,
  commandResult,
  windowEvent,
}

enum WindowCommand {
  requestSnapshot,
  completeReminder,
  skipReminder,
  openControlCenter,
  closeControlCenter,
  modifyInterval,
  toggleObedientMode,
  markChatRead,
  refreshGroups,
  refreshLeaderboard,
  loadChat,
  sendChat,
  createGroup,
  joinGroup,
  leaveGroup,
  updateAvatar,
  checkForUpdate,
  saveCustomMedia,
  removeCustomMedia,
  setBackgroundRemoval,
  clearLocalData,
  quit,
}

class WindowEnvelope {
  WindowEnvelope({
    required this.type,
    required this.revision,
    required this.payload,
    String? requestId,
  }) : requestId = requestId ?? const Uuid().v4();

  factory WindowEnvelope.decode(String value) {
    final json = jsonDecode(value) as Map<String, dynamic>;
    final version = (json['protocolVersion'] as num?)?.toInt();
    if (version != windowProtocolVersion) {
      throw const FormatException('Unsupported window protocol version');
    }
    return WindowEnvelope(
      type: WindowMessageType.values.byName(json['type'] as String),
      revision: (json['revision'] as num?)?.toInt() ?? 0,
      requestId: json['requestId'] as String?,
      payload:
          json['payload'] as Map<String, dynamic>? ?? const <String, dynamic>{},
    );
  }

  final WindowMessageType type;
  final int revision;
  final String requestId;
  final Map<String, dynamic> payload;

  String encode() => jsonEncode(<String, dynamic>{
        'protocolVersion': windowProtocolVersion,
        'type': type.name,
        'revision': revision,
        'requestId': requestId,
        'payload': payload,
      });

  static WindowEnvelope snapshot(AppSnapshot snapshot) => WindowEnvelope(
        type: WindowMessageType.stateSnapshot,
        revision: snapshot.revision,
        payload: snapshot.toJson(),
      );

  static WindowEnvelope command(
    WindowCommand command, {
    int revision = 0,
    Map<String, dynamic> arguments = const <String, dynamic>{},
  }) =>
      WindowEnvelope(
        type: WindowMessageType.command,
        revision: revision,
        payload: <String, dynamic>{
          'command': command.name,
          'arguments': arguments
        },
      );
}

class WindowLaunchArguments {
  const WindowLaunchArguments({
    required this.role,
    this.route,
    this.groupId,
    this.rootWindowId,
  });

  factory WindowLaunchArguments.decode(String? value) {
    if (value == null || value.isEmpty) {
      return const WindowLaunchArguments(role: WindowRole.pet);
    }
    final json = jsonDecode(value) as Map<String, dynamic>;
    return WindowLaunchArguments(
      role: WindowRole.values.byName(json['role'] as String? ?? 'pet'),
      route: json['route'] == null
          ? null
          : ControlRoute.values.byName(json['route'] as String),
      groupId: json['groupId'] as String?,
      rootWindowId: json['rootWindowId'] as String?,
    );
  }

  final WindowRole role;
  final ControlRoute? route;
  final String? groupId;
  final String? rootWindowId;

  String encode() => jsonEncode(<String, dynamic>{
        'role': role.name,
        'route': route?.name,
        'groupId': groupId,
        'rootWindowId': rootWindowId,
      });
}
