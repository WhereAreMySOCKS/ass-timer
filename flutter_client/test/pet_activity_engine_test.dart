import 'dart:math';

import 'package:ass_timer_flutter/domain/app_models.dart';
import 'package:ass_timer_flutter/domain/pet_activity_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts standing and can enter flight immediately', () {
    final events = <(PetActivityPhase, String, bool)>[];
    final engine = PetActivityEngine(
      random: Random(1),
      onChanged: (phase, sprite, facingLeft) {
        events.add((phase, sprite, facingLeft));
      },
    );
    addTearDown(engine.dispose);

    engine.start();
    engine.fly();

    expect(events.first.$1, PetActivityPhase.standing);
    expect(events.first.$2, '站立-1');
    expect(events.last.$1, PetActivityPhase.flying);
    expect(events.last.$2, '起飞');
  });

  test('nap is idempotent while already napping', () {
    final events = <(PetActivityPhase, String, bool)>[];
    final engine = PetActivityEngine(
      onChanged: (phase, sprite, facingLeft) {
        events.add((phase, sprite, facingLeft));
      },
    );
    addTearDown(engine.dispose);

    engine.nap();
    engine.nap();

    expect(engine.phase, PetActivityPhase.napping);
    expect(events, hasLength(1));
    expect(events.single.$2, '趴');
  });

  testWidgets('walk uses the same transition-in keyframes as SwiftUI',
      (tester) async {
    final sprites = <String>[];
    final engine = PetActivityEngine(
      random: Random(1),
      onChanged: (_, sprite, __) => sprites.add(sprite),
    );

    engine.start();
    await tester.pump(const Duration(seconds: 8));
    expect(engine.phase, PetActivityPhase.walking);
    expect(sprites.last, '站立-1');

    await tester.pump(const Duration(milliseconds: 350));
    expect(sprites.last, '站立-2');
    await tester.pump(const Duration(milliseconds: 350));
    expect(sprites.last, '走-2');
    await tester.pump(const Duration(milliseconds: 350));
    expect(sprites.last, '走-3');
    await tester.pump(const Duration(milliseconds: 350));
    expect(sprites.last, '走-2');
    expect(engine.isMoving, isTrue);
    engine.dispose();
    await tester.pump();
  });
}
