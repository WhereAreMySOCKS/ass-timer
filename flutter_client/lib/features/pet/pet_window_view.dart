import 'dart:async';
import 'dart:io';

import 'package:ass_timer_flutter/application/app_controller.dart';
import 'package:ass_timer_flutter/core/theme/app_theme.dart';
import 'package:ass_timer_flutter/core/window/desktop_host.dart';
import 'package:ass_timer_flutter/domain/app_models.dart';
import 'package:flutter/material.dart';
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
  bool _didPrecacheSprites = false;
  bool _flightInProgress = false;
  Timer? _hideTimer;
  Timer? _walkTimer;
  bool _moving = false;
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
    _ambientController.dispose();
    _clickController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final snapshot = controller.snapshot;
    DesktopHost.instance.onPetMoveSettled = controller.settlePetWindow;
    _syncWalking(controller);
    return Material(
      type: MaterialType.transparency,
      child: MouseRegion(
        onEnter: (_) {
          _hideTimer?.cancel();
          setState(() => _hovering = true);
        },
        onExit: (_) {
          _hideTimer?.cancel();
          _hideTimer = Timer(const Duration(milliseconds: 300), () {
            if (mounted) setState(() => _hovering = false);
          });
        },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (_) => DesktopHost.instance.startPetDrag(),
          onTap: () => _handleTap(controller),
          onDoubleTap: () => unawaited(_handleDoubleTap(controller)),
          onSecondaryTapDown: (details) =>
              _showContextMenu(details.globalPosition, controller),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: <Widget>[
              SizedBox(
                width: 164,
                height: 200,
                child: Center(child: _animatedPet(snapshot)),
              ),
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: _hovering ? 1 : 0,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 160),
                  child: IgnorePointer(
                    ignoring: !_hovering,
                    child: _PetActions(controller: controller),
                  ),
                ),
              ),
              if (controller.availableUpdate != null)
                Positioned(
                  left: 132,
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
                          color: Colors.orange,
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
                  left: 10,
                  right: 66,
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
                        style:
                            const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
                ),
            ],
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

  Future<void> _showContextMenu(
    Offset position,
    AppController controller,
  ) async {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: <PopupMenuEntry<String>>[
        const PopupMenuItem(value: 'chat', child: Text('群聊')),
        const PopupMenuItem(value: 'rank', child: Text('排行榜')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'timer', child: Text('修改间隔…')),
        const PopupMenuItem(value: 'settings', child: Text('设置…')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'quit', child: Text('退出')),
      ],
    );
    switch (selected) {
      case 'chat':
        await controller.openControlCenter(ControlRoute.chat);
      case 'rank':
        await controller.openControlCenter(ControlRoute.leaderboard);
      case 'timer':
        await controller.openControlCenter(ControlRoute.timer);
      case 'settings':
        await controller.openControlCenter(ControlRoute.timer);
      case 'quit':
        await DesktopHost.instance.quit();
    }
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

class _PetActions extends StatelessWidget {
  const _PetActions({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    const rightArc = <Offset>[
      Offset(138, 43),
      Offset(153, 70),
      Offset(158, 100),
      Offset(153, 130),
      Offset(138, 157),
    ];
    final dockedRight = controller.snapshot.dockSide == PetDockSide.right;
    final positions = dockedRight
        ? rightArc
            .map((point) => Offset(164 - point.dx, point.dy))
            .toList(growable: false)
        : rightArc;
    final unread = controller.snapshot.unreadCounts.values
        .fold<int>(0, (total, count) => total + count);
    final obedient = controller.snapshot.config.appMode == AppMode.obedient;
    final buttons = <_ActionButton>[
      _ActionButton(
        tooltip: '设置',
        icon: Icons.settings_outlined,
        onPressed: () => controller.openControlCenter(ControlRoute.timer),
      ),
      _ActionButton(
        tooltip: unread > 0 ? '发言，$unread 条未读消息' : '发言',
        icon: Icons.chat_bubble_outline,
        badgeCount: unread,
        onPressed: () => controller.openControlCenter(ControlRoute.chat),
      ),
      _ActionButton(
        tooltip: '奖杯',
        icon: Icons.emoji_events_outlined,
        onPressed: () => controller.openControlCenter(ControlRoute.leaderboard),
      ),
      _ActionButton(
        tooltip: obedient ? '切换到普通模式' : '开启听话模式',
        icon: obedient ? Icons.eco : Icons.eco_outlined,
        selected: obedient,
        onPressed: controller.toggleObedientMode,
      ),
      _ActionButton(
        tooltip: '退出',
        icon: Icons.power_settings_new,
        onPressed: DesktopHost.instance.quit,
      ),
    ];

    return Stack(
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
      this.selected = false});

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final int badgeCount;
  final bool selected;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: widget.tooltip,
        child: MouseRegion(
          onEnter: (_) => setState(() => hovering = true),
          onExit: (_) => setState(() => hovering = false),
          child: Semantics(
            button: true,
            label: widget.tooltip,
            child: IconButton(
              onPressed: widget.onPressed,
              padding: EdgeInsets.zero,
              icon: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.selected
                          ? Colors.orange
                              .withValues(alpha: hovering ? 0.24 : 0.16)
                          : Colors.black
                              .withValues(alpha: hovering ? 0.11 : 0.001),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      widget.icon,
                      size: 18,
                      color: widget.selected ? Colors.orange : AppColors.text,
                    ),
                  ),
                  if (widget.badgeCount > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        constraints:
                            const BoxConstraints(minWidth: 14, minHeight: 14),
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: const BoxDecoration(
                          color: Colors.red,
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
      );
}
