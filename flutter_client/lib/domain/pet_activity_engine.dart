import 'dart:async';
import 'dart:math';

import 'package:ass_timer_flutter/domain/app_models.dart';

class PetActivityEngine {
  PetActivityEngine({required this.onChanged, Random? random})
      : _random = random ?? Random();

  final void Function(PetActivityPhase phase, String sprite, bool facingLeft)
      onChanged;
  final Random _random;

  static const List<String> _standingFrames = <String>['站立-1', '站立-2'];
  static const List<String> _walkTransitionIn = <String>[
    '站立-1',
    '站立-2',
    '走-2',
    '走-3',
  ];
  static const List<String> _walkLoop = <String>[
    '走-2',
    '走-3',
    '走-2',
    '走-4',
  ];
  static const List<String> _walkTransitionOut = <String>[
    '走-4',
    '走-2',
    '站立-2',
    '站立-1',
  ];

  Timer? _phaseTimer;
  Timer? _frameTimer;
  Timer? _napTimer;
  PetActivityPhase phase = PetActivityPhase.standing;
  bool facingLeft = false;
  int _frame = 0;
  _WalkFramePhase _walkFramePhase = _WalkFramePhase.transitionIn;
  DateTime _walkEndAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool isMoving = false;

  void start() {
    stop();
    _startStanding();
    _napTimer = Timer.periodic(const Duration(minutes: 15), (_) => nap());
  }

  void stop() {
    _phaseTimer?.cancel();
    _frameTimer?.cancel();
    _napTimer?.cancel();
    _phaseTimer = null;
    _frameTimer = null;
    _napTimer = null;
    isMoving = false;
    phase = PetActivityPhase.standing;
  }

  void fly() {
    _phaseTimer?.cancel();
    _frameTimer?.cancel();
    phase = PetActivityPhase.flying;
    isMoving = false;
    facingLeft = _random.nextBool();
    onChanged(phase, '起飞', facingLeft);
    _phaseTimer = Timer(const Duration(milliseconds: 1600), _startStanding);
  }

  void nap() {
    if (phase == PetActivityPhase.napping) return;
    _phaseTimer?.cancel();
    _frameTimer?.cancel();
    phase = PetActivityPhase.napping;
    isMoving = false;
    facingLeft = false;
    onChanged(phase, '趴', false);
    _phaseTimer = Timer(const Duration(minutes: 1), _startStanding);
  }

  void dispose() => stop();

  /// Keeps animation frames in sync when the window reverses at an edge.
  void setFacingLeft(bool value) {
    facingLeft = value;
  }

  void _startStanding() {
    _phaseTimer?.cancel();
    _frameTimer?.cancel();
    phase = PetActivityPhase.standing;
    isMoving = false;
    facingLeft = false;
    _frame = 0;
    onChanged(phase, _standingFrames.first, false);
    _frameTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      _frame = (_frame + 1) % _standingFrames.length;
      onChanged(phase, _standingFrames[_frame], false);
    });
    _phaseTimer = Timer(const Duration(seconds: 8), _startWalking);
  }

  void _startWalking() {
    _phaseTimer?.cancel();
    _frameTimer?.cancel();
    phase = PetActivityPhase.walking;
    facingLeft = _random.nextBool();
    isMoving = true;
    _frame = 0;
    _walkFramePhase = _WalkFramePhase.transitionIn;
    _walkEndAt = DateTime.now().add(
      Duration(milliseconds: 3000 + _random.nextInt(12001)),
    );
    onChanged(phase, _walkTransitionIn.first, facingLeft);
    _scheduleNextWalkFrame();
  }

  void _scheduleNextWalkFrame() {
    _frameTimer?.cancel();
    final frames = _framesFor(_walkFramePhase);
    final current = frames[_frame];
    final extra = current == '走-4' ? 150 : 0;
    _frameTimer = Timer(Duration(milliseconds: 350 + extra), _advanceWalkFrame);
  }

  void _advanceWalkFrame() {
    switch (_walkFramePhase) {
      case _WalkFramePhase.transitionIn:
        if (_frame + 1 < _walkTransitionIn.length) {
          _frame += 1;
        } else {
          _walkFramePhase = _WalkFramePhase.loop;
          _frame = 0;
        }
      case _WalkFramePhase.loop:
        if (!DateTime.now().isBefore(_walkEndAt)) {
          _walkFramePhase = _WalkFramePhase.transitionOut;
          _frame = 0;
          isMoving = false;
        } else {
          _frame = (_frame + 1) % _walkLoop.length;
        }
      case _WalkFramePhase.transitionOut:
        if (_frame + 1 < _walkTransitionOut.length) {
          _frame += 1;
        } else {
          _startStanding();
          return;
        }
    }
    onChanged(phase, _framesFor(_walkFramePhase)[_frame], facingLeft);
    _scheduleNextWalkFrame();
  }

  List<String> _framesFor(_WalkFramePhase framePhase) => switch (framePhase) {
        _WalkFramePhase.transitionIn => _walkTransitionIn,
        _WalkFramePhase.loop => _walkLoop,
        _WalkFramePhase.transitionOut => _walkTransitionOut,
      };
}

enum _WalkFramePhase { transitionIn, loop, transitionOut }
