import 'package:ass_timer_flutter/core/window/desktop_host.dart';
import 'package:ass_timer_flutter/domain/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows keeps bubbles in the root window and skips chat prewarm', () {
    expect(
      shouldUseSeparateBubbleWindow(TargetPlatform.windows),
      isFalse,
    );
    expect(shouldPrewarmChatWindow(TargetPlatform.windows), isFalse);
    expect(shouldUseSeparateBubbleWindow(TargetPlatform.macOS), isTrue);
    expect(shouldPrewarmChatWindow(TargetPlatform.macOS), isTrue);
  });

  test('obedient mode docks the sprite flush with the left screen edge', () {
    final position = calculateDockedPetPosition(
      visiblePosition: const Offset(0, 24),
      visibleSize: const Size(1440, 876),
      currentY: 640,
      side: PetDockSide.left,
    );

    expect(position.dx, -28);
    expect(position.dx + 28, 0);
    expect(position.dy, 640);
  });

  test('right docking mirrors the 108 point sprite', () {
    final position = calculateDockedPetPosition(
      visiblePosition: const Offset(1440, 0),
      visibleSize: const Size(1920, 1080),
      currentY: 1000,
      side: PetDockSide.right,
    );

    expect(position.dx, 3224);
    expect(position.dx + 28 + 108, 3360);
    expect(position.dy, 880);
  });
}
