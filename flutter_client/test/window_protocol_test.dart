import 'package:ass_timer_flutter/core/window/window_protocol.dart';
import 'package:ass_timer_flutter/domain/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('window command round-trips with protocol metadata', () {
    final encoded = WindowEnvelope.command(
      WindowCommand.modifyInterval,
      revision: 7,
      arguments: <String, dynamic>{'seconds': 900},
    ).encode();

    final decoded = WindowEnvelope.decode(encoded);

    expect(decoded.type, WindowMessageType.command);
    expect(decoded.revision, 7);
    expect(decoded.payload['command'], 'modifyInterval');
  });

  test('launch arguments preserve the root window id', () {
    final original = WindowLaunchArguments(
      role: WindowRole.controlCenter,
      route: ControlRoute.chat,
      groupId: 'group-1',
      rootWindowId: 'root-1',
    );

    final decoded = WindowLaunchArguments.decode(original.encode());

    expect(decoded.role, WindowRole.controlCenter);
    expect(decoded.route, ControlRoute.chat);
    expect(decoded.rootWindowId, 'root-1');
  });

  test('clear local data command is protocol-safe', () {
    final decoded = WindowEnvelope.decode(
      WindowEnvelope.command(WindowCommand.clearLocalData).encode(),
    );

    expect(decoded.payload['command'], 'clearLocalData');
  });
}
