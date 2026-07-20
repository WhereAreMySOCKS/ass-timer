import 'dart:async';
import 'dart:io';

import 'package:ass_timer_flutter/application/app_controller.dart';
import 'package:ass_timer_flutter/core/theme/app_theme.dart';
import 'package:ass_timer_flutter/core/window/desktop_host.dart';
import 'package:ass_timer_flutter/domain/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class PetWindowView extends ConsumerStatefulWidget {
  const PetWindowView({super.key});

  @override
  ConsumerState<PetWindowView> createState() => _PetWindowViewState();
}

class _PetWindowViewState extends ConsumerState<PetWindowView>
    with TickerProviderStateMixin {
  static const List<String> _spriteAssets = <String>[
    'assets/pets/pet_deer.png',
    'assets/sprites/站立-1.png',
    'assets/sprites/站立-2.png',
    'assets/sprites/走-2.png',
    'assets/sprites/走-3.png',
    'assets/sprites/走-4.png',
    'assets/sprites/起飞.png',
    'assets/sprites/趴.png',
    'assets/sprites/停止.png',
    'assets/sprites/得意.png',
    'assets/sprites/愤怒.png',
    'assets/sprites/哇.png',
    'assets/sprites/后视镜.png',
  ];

  bool _hovering = false;
  bool _menuPinned = false;
  bool _bubbleOwnedLastFrame = false;
  bool _didPrecacheSprites = false;
  bool _flightInProgress = false;
  Timer? _hideTimer;
  Timer? _walkTimer;
  bool _moving = false;
  final FocusNode _menuFocus = FocusNode(debugLabel: 'pet-actions');
  late final AnimationController _ambientController;
  late final AnimationController _clickController;
  late final Animation<double> _clickScale;
  late final Animation<double> _clickLift;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _clickController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 270),
    );
    _clickScale = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 0.88)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.88, end: 1)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 2,
      ),
    ]).animate(_clickController);
    _clickLift = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 4),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 4, end: 0),
        weight: 2,
      ),
    ]).animate(_clickController);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _ambientController.stop();
      _ambientController.value = 0.5;
    } else if (!_ambientController.isAnimating) {
      _ambientController.repeat(reverse: true);
    }
    if (_didPrecacheSprites) return;
    _didPrecacheSprites = true;
    for (final asset in _spriteAssets) {
      precacheImage(AssetImage(asset), context);
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _walkTimer?.cancel();
    _menuFocus.dispose();
    _ambientController.dispose();
    _clickController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final snapshot = controller.snapshot;
    final petVisualLeft = petVisualLeftForDockSide(snapshot.dockSide);
    final bubbleOwnsInteraction = bubbleOwnsPetInteraction(snapshot.bubbles);
    final showPetActions = !bubbleOwnsInteraction && (_hovering || _menuPinned);
    if (bubbleOwnsInteraction && !_bubbleOwnedLastFrame && _menuPinned) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _dismissActions();
      });
    }
    _bubbleOwnedLastFrame = bubbleOwnsInteraction;
    DesktopHost.instance.onPetMoveSettled = controller.settlePetWindow;
    _syncWalking(controller);
    return Material(
      type: MaterialType.transparency,
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): _closePinnedMenu,
        },
        child: Focus(
          focusNode: _menuFocus,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _menuPinned ? _closePinnedMenu : null,
            child: MouseRegion(
              onEnter: (_) {
                _hideTimer?.cancel();
                setState(() => _hovering = true);
              },
              onExit: (_) {
                _hideTimer?.cancel();
                _hideTimer = Timer(const Duration(milliseconds: 300), () {
                  if (mounted && !_menuPinned) {
                    setState(() => _hovering = false);
                  }
                });
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned(
                    left: petVisualLeft,
                    top: 0,
                    width: petVisualAreaWidth,
                    height: petWindowSize.height,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onPanStart: (_) => DesktopHost.instance.startPetDrag(),
                      onTap: () {
                        if (_menuPinned) _closePinnedMenu();
                        _handleTap(controller);
                      },
                      onDoubleTap: () =>
                          unawaited(_handleDoubleTap(controller)),
                      onSecondaryTapDown: bubbleOwnsInteraction
                          ? null
                          : (_) => _togglePinnedMenu(),
                      child: Center(child: _animatedPet(snapshot)),
                    ),
                  ),
                  Positioned.fill(
                    child: AnimatedOpacity(
                      opacity: showPetActions ? 1 : 0,
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 160),
                      child: IgnorePointer(
                        ignoring: !showPetActions,
                        child: _PetActions(
                          controller: controller,
                          expanded: _menuPinned,
                          onActionInvoked: _dismissActions,
                        ),
                      ),
                    ),
                  ),
                  if (controller.availableUpdate != null)
                    Positioned(
                      left: petVisualLeft + 132,
                      top: 18,
                      child: Tooltip(
                        message:
                            '发现新版本 ${controller.availableUpdate!.latestVersion}',
                        child: InkWell(
                          onTap: () => launchUrl(
                            Uri.parse(controller.availableUpdate!.downloadUrl),
                          ),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 18,
                            height: 18,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppColors.coral,
                              shape: BoxShape.circle,
                            ),
                            child: const Text(
                              '!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (snapshot.lastError != null)
                    Positioned(
                      left: petVisualLeft + 10,
                      right: snapshot.dockSide == PetDockSide.right ? 10 : 66,
                      bottom: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.76),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          child: Text(
                            snapshot.lastError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _animatedPet(AppSnapshot snapshot) => AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[
          _ambientController,
          _clickController,
        ]),
        child: _PetSprite(snapshot: snapshot),
        builder: (context, child) {
          final canBob = snapshot.timerPhase == TimerPhase.running &&
              snapshot.petActivityPhase == PetActivityPhase.standing &&
              snapshot.dockSide == null;
          final bob = canBob ? (_ambientController.value * 4) - 2 : 0.0;
          final pulse = snapshot.timerPhase == TimerPhase.reminder
              ? 0.97 + _ambientController.value * 0.06
              : 1.0;
          return Transform.translate(
            offset: Offset(0, bob + _clickLift.value),
            child: Transform.scale(
              scale: pulse * _clickScale.value,
              child: child,
            ),
          );
        },
      );

  void _handleTap(AppController controller) {
    controller.interact();
    if (!MediaQuery.disableAnimationsOf(context)) {
      _clickController.forward(from: 0);
    }
  }

  Future<void> _handleDoubleTap(AppController controller) async {
    if (controller.snapshot.timerPhase == TimerPhase.reminder) {
      await controller.completeReminder();
      return;
    }
    if (controller.snapshot.config.appMode == AppMode.obedient ||
        _flightInProgress) {
      return;
    }
    _flightInProgress = true;
    controller.fly();
    try {
      await DesktopHost.instance.performPetFlight(
        controller.snapshot.petFacingLeft,
        onDirectionResolved: controller.setPetFacingLeft,
      );
      await controller.settlePetWindow();
    } finally {
      _flightInProgress = false;
    }
  }

  void _syncWalking(AppController controller) {
    final walking = controller.isPetMoving;
    if (walking && _walkTimer == null) {
      _walkTimer = Timer.periodic(const Duration(milliseconds: 50), (_) async {
        if (_moving) return;
        _moving = true;
        try {
          final facingLeft = controller.snapshot.petFacingLeft;
          final next = await DesktopHost.instance.movePetStep(facingLeft);
          if (next != facingLeft) controller.setPetFacingLeft(next);
        } finally {
          _moving = false;
        }
      });
    } else if (!walking && _walkTimer != null) {
      _walkTimer?.cancel();
      _walkTimer = null;
    }
  }

  void _togglePinnedMenu() {
    _hideTimer?.cancel();
    setState(() {
      _menuPinned = !_menuPinned;
      _hovering = _menuPinned || _hovering;
    });
    if (_menuPinned) _menuFocus.requestFocus();
  }

  void _closePinnedMenu() {
    if (!_menuPinned) return;
    _dismissActions();
  }

  void _dismissActions() {
    if (!_menuPinned && !_hovering) return;
    setState(() {
      _menuPinned = false;
      _hovering = false;
    });
  }
}

class _PetSprite extends StatelessWidget {
  const _PetSprite({required this.snapshot});

  final AppSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final sprite = resolveDefaultPetSprite(
      currentSprite: snapshot.currentSprite,
      appMode: snapshot.config.appMode,
      dockSide: snapshot.dockSide,
    );
    final customEntry = snapshot.config.customActionMedia[_customSlot()];
    final asset = sprite == null
        ? 'assets/pets/pet_deer.png'
        : 'assets/sprites/$sprite.png';
    return Semantics(
      image: true,
      label: snapshot.timerPhase == TimerPhase.reminder ? '提醒中的小鹿' : '桌面宠物小鹿',
      child: customEntry == null
          ? _assetImage(context, asset)
          : FutureBuilder<String>(
              future: _customPath(customEntry),
              builder: (context, pathSnapshot) {
                final filePath = pathSnapshot.data;
                if (filePath == null) return _assetImage(context, asset);
                return Transform.flip(
                  flipX: _shouldFlip,
                  child: Image.file(
                    File(filePath),
                    width: 108,
                    height: 144,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.high,
                    isAntiAlias: true,
                    errorBuilder: (_, __, ___) => _assetImage(context, asset),
                  ),
                );
              },
            ),
    );
  }

  Widget _assetImage(BuildContext context, String asset) => RepaintBoundary(
          child: Transform.flip(
        flipX: _shouldFlip,
        child: Image.asset(
          asset,
          width: 108,
          height: 144,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          filterQuality: FilterQuality.high,
          isAntiAlias: true,
          errorBuilder: (_, __, ___) => Image.asset(
            'assets/pets/pet_deer.png',
            width: 108,
            height: 144,
            gaplessPlayback: true,
          ),
        ),
      ));

  bool get _shouldFlip => snapshot.dockSide != null
      ? snapshot.dockSide == PetDockSide.right
      : snapshot.petFacingLeft;

  String _customSlot() {
    if (snapshot.timerPhase == TimerPhase.reminder) return 'reminder';
    if (snapshot.timerPhase == TimerPhase.confirming) return 'completion';
    if (snapshot.petActivityPhase == PetActivityPhase.napping) return 'nap';
    if (snapshot.dockSide != null) return 'docked';
    if (snapshot.config.appMode == AppMode.obedient) return 'obedientPet';
    if (snapshot.currentSprite == '愤怒') return 'interaction';
    return '';
  }

  Future<String> _customPath(CustomActionMediaEntry entry) async {
    final base = await getApplicationSupportDirectory();
    final root = Platform.isMacOS
        ? p.join(base.parent.path, 'AssTimer')
        : p.join(base.path, 'AssTimer');
    final name = entry.removesBackground && entry.foregroundFileName != null
        ? entry.foregroundFileName!
        : entry.backgroundFileName;
    return p.join(root, 'custom-actions', name);
  }
}

@visibleForTesting
String? resolveDefaultPetSprite({
  required String? currentSprite,
  required AppMode appMode,
  required PetDockSide? dockSide,
}) {
  if (appMode == AppMode.obedient && dockSide != null) return '后视镜';
  if (appMode == AppMode.obedient) return '得意';
  return currentSprite;
}

@visibleForTesting
bool bubbleOwnsPetInteraction(Iterable<BubbleItem> bubbles) => bubbles.any(
      (bubble) =>
          bubble.kind == BubbleKind.reminder ||
          bubble.kind == BubbleKind.feedback,
    );

@visibleForTesting
List<Offset> petActionCenters(
  PetDockSide? dockSide, {
  bool expanded = true,
}) {
  const quickRightArc = <Offset>[
    Offset(145, 48),
    Offset(158, 100),
    Offset(145, 152),
  ];
  const expandedRightArc = <Offset>[
    Offset(107, 24),
    Offset(147, 53),
    Offset(158, 100),
    Offset(147, 147),
    Offset(107, 176),
  ];
  final rightArc = expanded ? expandedRightArc : quickRightArc;
  if (dockSide != PetDockSide.right) return rightArc;
  final visualLeft = petVisualLeftForDockSide(dockSide);
  return rightArc
      .map(
        (point) => Offset(
          visualLeft + petVisualAreaWidth - point.dx,
          point.dy,
        ),
      )
      .toList(growable: false);
}

class _PetActions extends StatelessWidget {
  const _PetActions({
    required this.controller,
    required this.expanded,
    required this.onActionInvoked,
  });

  final AppController controller;
  final bool expanded;
  final VoidCallback onActionInvoked;

  @override
  Widget build(BuildContext context) {
    final positions = petActionCenters(
      controller.snapshot.dockSide,
      expanded: expanded,
    );
    final unread = controller.snapshot.unreadCounts.values
        .fold<int>(0, (total, count) => total + count);
    final obedient = controller.snapshot.config.appMode == AppMode.obedient;
    final quickButtons = <_ActionButton>[
      _ActionButton(
        tooltip: '设置',
        icon: Icons.settings_rounded,
        onPressed: () {
          onActionInvoked();
          controller.openControlCenter(ControlRoute.timer);
        },
      ),
      _ActionButton(
        tooltip: unread > 0 ? '发言，$unread 条未读消息' : '发言',
        icon: Icons.chat_bubble_rounded,
        badgeCount: unread,
        onPressed: () {
          onActionInvoked();
          controller.openControlCenter(ControlRoute.chat);
        },
      ),
      _ActionButton(
        tooltip: obedient ? '切换到普通模式' : '开启听话模式',
        icon: Icons.eco_rounded,
        selected: obedient,
        onPressed: () {
          onActionInvoked();
          controller.toggleObedientMode();
        },
      ),
    ];
    final buttons = expanded
        ? <_ActionButton>[
            ...quickButtons,
            _ActionButton(
              tooltip: '排行榜',
              icon: Icons.emoji_events_rounded,
              onPressed: () {
                onActionInvoked();
                controller.openControlCenter(ControlRoute.leaderboard);
              },
            ),
            _ActionButton(
              tooltip: '退出',
              icon: Icons.power_settings_new_rounded,
              danger: true,
              onPressed: () {
                onActionInvoked();
                DesktopHost.instance.quit();
              },
            ),
          ]
        : quickButtons;

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        for (var index = 0; index < buttons.length; index++)
          Positioned(
            left: positions[index].dx - 22,
            top: positions[index].dy - 22,
            width: 44,
            height: 44,
            child: buttons[index],
          ),
      ],
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton(
      {required this.tooltip,
      required this.icon,
      required this.onPressed,
      this.badgeCount = 0,
      this.selected = false,
      this.danger = false});

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final int badgeCount;
  final bool selected;
  final bool danger;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool hovering = false;
  bool pressed = false;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: widget.tooltip,
        child: MouseRegion(
          onEnter: (_) => setState(() => hovering = true),
          onExit: (_) => setState(() => hovering = false),
          child: Semantics(
            button: true,
            label: widget.tooltip,
            child: AnimatedScale(
              scale: pressed ? 0.94 : 1,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : context.visualTokens.hoverDuration,
              child: Listener(
                onPointerDown: (_) => setState(() => pressed = true),
                onPointerUp: (_) => setState(() => pressed = false),
                onPointerCancel: (_) => setState(() => pressed = false),
                child: IconButton(
                  onPressed: widget.onPressed,
                  padding: EdgeInsets.zero,
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      AnimatedContainer(
                        duration: context.visualTokens.hoverDuration,
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: pressed
                              ? Colors.white.withValues(alpha: 0.22)
                              : hovering || widget.selected
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.transparent,
                          border: Border.all(
                            color: widget.danger
                                ? AppColors.coral.withValues(alpha: 0.82)
                                : hovering || widget.selected
                                    ? Colors.white.withValues(alpha: 0.92)
                                    : Colors.white.withValues(alpha: 0.58),
                            width: hovering || widget.selected ? 1.5 : 1,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.28),
                              blurRadius: hovering || pressed ? 12 : 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          widget.icon,
                          size: 18,
                          color: widget.danger
                              ? AppColors.coral
                              : Colors.white.withValues(
                                  alpha: widget.selected || hovering ? 1 : 0.82,
                                ),
                        ),
                      ),
                      if (widget.badgeCount > 0)
                        Positioned(
                          right: -6,
                          top: -6,
                          child: Container(
                            constraints: const BoxConstraints(
                                minWidth: 14, minHeight: 14),
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: const BoxDecoration(
                              color: AppColors.coral,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              widget.badgeCount > 99
                                  ? '99+'
                                  : '${widget.badgeCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(44),
                    maximumSize: const Size.square(44),
                    foregroundColor: AppColors.text,
                    overlayColor: Colors.transparent,
                    shape: const CircleBorder(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
