import 'package:ass_timer_flutter/domain/app_models.dart';
import 'package:ass_timer_flutter/features/pet/pet_window_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('docked obedient mode always uses the rear-view sprite', () {
    expect(
      resolveDefaultPetSprite(
        currentSprite: '得意',
        appMode: AppMode.obedient,
        dockSide: PetDockSide.left,
      ),
      '后视镜',
    );
  });

  test('undocked obedient mode uses the obedient sprite', () {
    expect(
      resolveDefaultPetSprite(
        currentSprite: '站立-1',
        appMode: AppMode.obedient,
        dockSide: null,
      ),
      '得意',
    );
  });
}
