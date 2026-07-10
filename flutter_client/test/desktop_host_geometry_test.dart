import 'package:ass_timer_flutter/core/window/desktop_host.dart';
import 'package:ass_timer_flutter/core/window/bubble_layout.dart';
import 'package:ass_timer_flutter/domain/app_models.dart';
import 'package:ass_timer_flutter/features/pet/pet_window_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('macOS and Windows both use the dedicated bubble window', () {
    expect(
      shouldUseSeparateBubbleWindow(TargetPlatform.windows),
      isTrue,
    );
    expect(shouldUseSeparateBubbleWindow(TargetPlatform.macOS), isTrue);
  });

  test('obedient bubble overlaps the pet window to stay visually attached', () {
    final position = calculateBubbleWindowPosition(
      petPosition: const Offset(-28, 400),
      petSize: dockedPetWindowSize,
      bubbleSize: obedientBubbleContentSize,
      visiblePosition: const Offset(0, 24),
      visibleSize: const Size(1440, 876),
      dockSide: PetDockSide.left,
      obedient: true,
    );

    expect(position.dx, 128);
    expect(position.dy, 462);
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

    expect(position.dx, 3204);
    expect(
      position.dx +
          petVisualLeftForDockSide(PetDockSide.right) +
          petSpriteLeadingInset +
          petSpriteWidth,
      3360,
    );
    expect(position.dy, 880);
  });

  test('bubble stays on screen and opens into the desktop from a left dock',
      () {
    final position = calculateBubbleWindowPosition(
      petPosition: const Offset(-28, 400),
      petSize: dockedPetWindowSize,
      bubbleSize: bubbleWindowSize,
      visiblePosition: const Offset(0, 24),
      visibleSize: const Size(1440, 876),
      dockSide: PetDockSide.left,
    );

    expect(position.dx, greaterThanOrEqualTo(8));
    expect(position.dy, 398);
  });

  test('free-roaming bubble is centred above its pet', () {
    final position = calculateBubbleWindowPosition(
      petPosition: const Offset(500, 500),
      petSize: petWindowSize,
      bubbleSize: bubbleWindowSize,
      visiblePosition: Offset.zero,
      visibleSize: const Size(1440, 900),
    );

    expect(position, const Offset(456, 316));
  });

  test('docked action circles and shadows stay inside the native window', () {
    for (final side in PetDockSide.values) {
      final centers = petActionCenters(side);
      for (final center in centers) {
        expect(center.dx - 26, greaterThanOrEqualTo(0));
        expect(center.dx + 26, lessThanOrEqualTo(dockedPetWindowSize.width));
      }
    }
  });
}
