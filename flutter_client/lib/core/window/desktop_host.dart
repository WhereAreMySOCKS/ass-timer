import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:ass_timer_flutter/core/diagnostics/crash_reporter.dart';
import 'package:ass_timer_flutter/core/window/serialized_async_throttle.dart';
import 'package:ass_timer_flutter/core/window/window_protocol.dart';
import 'package:ass_timer_flutter/domain/app_models.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

@visibleForTesting
Offset calculateDockedPetPosition({
  required Offset visiblePosition,
  required Size visibleSize,
  required double currentY,
  required PetDockSide side,
}) {
  const dockedSize = Size(164, 200);
  final x = side == PetDockSide.left
      ? visiblePosition.dx - 28
      : visiblePosition.dx + visibleSize.width - 108 - 28;
  final maxY = visiblePosition.dy + visibleSize.height - dockedSize.height;
  return Offset(x, currentY.clamp(visiblePosition.dy, maxY));
}

bool shouldUseSeparateBubbleWindow(TargetPlatform platform) =>
    platform != TargetPlatform.windows;

bool shouldPrewarmChatWindow(TargetPlatform platform) =>
    platform != TargetPlatform.windows;

class StartupResult {
  const StartupResult({
    required this.launchArguments,
    required this.trayAvailable,
    this.startupWarnings = const <String>[],
  });

  final WindowLaunchArguments launchArguments;
  final bool trayAvailable;
  final List<String> startupWarnings;
}

@visibleForTesting
Future<bool> initializeTrayWithFallback({
  required Future<void> Function() initialize,
  required Future<void> Function() showTaskbarFallback,
  required Future<void> Function(Object error, StackTrace stack) report,
}) async {
  try {
    await initialize();
    return true;
  } on Object catch (error, stack) {
    await report(error, stack);
    await showTaskbarFallback();
    return false;
  }
}

class DesktopHost with TrayListener, WindowListener {
  DesktopHost._();

  static final DesktopHost instance = DesktopHost._();

  WindowController? _settingsWindow;
  WindowController? _chatWindow;
  WindowController? _leaderboardWindow;
  Future<WindowController>? _chatWindowCreation;
  WindowController? _bubbleWindow;
  WindowController? _currentWindow;
  WindowLaunchArguments? _launchArguments;
  final List<WindowController> _children = <WindowController>[];
  Future<dynamic> Function(WindowEnvelope envelope)? _rootCommandHandler;
  VoidCallback? onTrayTogglePet;
  VoidCallback? onTrayQuit;
  Future<void> Function(ControlRoute route)? onOpenControlCenter;
  final StreamController<String> _windowsPowerEvents =
      StreamController<String>.broadcast();
  Timer? _moveSettledTimer;
  VoidCallback? onPetMoveSettled;
  final SerializedAsyncThrottle _bubbleAnchorThrottle = SerializedAsyncThrottle(
    const Duration(milliseconds: 33),
  );
  bool _disposed = false;
  bool _trayAvailable = true;

  Future<StartupResult> initializeCurrentWindow() async {
    await windowManager.ensureInitialized();
    final controller = await WindowController.fromCurrentEngine();
    final arguments = WindowLaunchArguments.decode(controller.arguments);
    _currentWindow = controller;
    _launchArguments = arguments;
    final options = switch (arguments.role) {
      WindowRole.pet => const WindowOptions(
          size: Size(224, 200),
          backgroundColor: Colors.transparent,
          skipTaskbar: true,
          titleBarStyle: TitleBarStyle.hidden,
          alwaysOnTop: true,
        ),
      WindowRole.bubble => const WindowOptions(
          size: Size(320, 220),
          backgroundColor: Colors.transparent,
          skipTaskbar: true,
          titleBarStyle: TitleBarStyle.hidden,
          alwaysOnTop: true,
        ),
      WindowRole.controlCenter => WindowOptions(
          size: _controlSizeFor(arguments.route ?? ControlRoute.timer),
          minimumSize:
              (arguments.route ?? ControlRoute.timer) == ControlRoute.chat
                  ? const Size(560, 380)
                  : _controlSizeFor(arguments.route ?? ControlRoute.timer),
          center: true,
          backgroundColor: Colors.white,
          skipTaskbar: false,
          titleBarStyle: TitleBarStyle.normal,
        ),
    };
    await windowManager.waitUntilReadyToShow(options, () async {
      if (arguments.role != WindowRole.controlCenter) {
        await windowManager.setAsFrameless();
        await windowManager.setHasShadow(false);
        await windowManager.setAlwaysOnTop(true);
        await windowManager.setVisibleOnAllWorkspaces(
          true,
          visibleOnFullScreen: true,
        );
      }
      await windowManager.show(inactive: arguments.role == WindowRole.bubble);
    });
    if (arguments.role == WindowRole.controlCenter) {
      await _resizeControlWindow(arguments.route ?? ControlRoute.timer);
    }
    var trayAvailable = !Platform.isWindows || arguments.role != WindowRole.pet;
    final startupWarnings = <String>[];
    if (Platform.isWindows && arguments.role == WindowRole.pet) {
      const MethodChannel(
        'ass_timer/power_events_windows',
      ).setMethodCallHandler((call) async {
        if (call.method == 'powerEvent' && call.arguments is String) {
          _windowsPowerEvents.add(call.arguments as String);
        }
      });
      trayAvailable = await initializeTrayWithFallback(
        initialize: _initializeWindowsTray,
        report: (error, stack) => CrashReporter.instance.record(
          error,
          stack,
          context: 'windows_tray_startup',
        ),
        showTaskbarFallback: () => windowManager.setSkipTaskbar(false),
      );
      if (!trayAvailable) {
        startupWarnings.add('系统托盘初始化失败，已保留任务栏入口。');
        trayManager.removeListener(this);
      }
      _trayAvailable = trayAvailable;
    }
    windowManager.addListener(this);
    return StartupResult(
      launchArguments: arguments,
      trayAvailable: trayAvailable,
      startupWarnings: List<String>.unmodifiable(startupWarnings),
    );
  }

  WindowLaunchArguments get launchArguments =>
      _launchArguments ?? const WindowLaunchArguments(role: WindowRole.pet);

  bool get usesSeparateBubbleWindow =>
      shouldUseSeparateBubbleWindow(defaultTargetPlatform);

  Future<void> bindRoot(
    Future<dynamic> Function(WindowEnvelope envelope) commandHandler,
  ) async {
    _rootCommandHandler = commandHandler;
    await _currentWindow?.setWindowMethodHandler((call) async {
      if (call.method == 'childClosed' && call.arguments is String) {
        _forgetChild(call.arguments as String);
        return true;
      }
      if (call.method != 'command' || call.arguments is! String) return null;
      return _rootCommandHandler?.call(
        WindowEnvelope.decode(call.arguments as String),
      );
    });
  }

  Future<void> bindReplica(
    void Function(Map<String, dynamic> payload, int revision) onState, {
    void Function(ControlRoute route, String? groupId)? onNavigate,
  }) async {
    await _currentWindow?.setWindowMethodHandler((call) async {
      if (call.method == 'close') {
        await windowManager.close();
        return true;
      }
      if (call.method == 'anchor' && call.arguments is Map) {
        final anchor = (call.arguments as Map).cast<String, dynamic>();
        await windowManager.setPosition(
          Offset(
            (anchor['x'] as num).toDouble() - 48,
            (anchor['y'] as num).toDouble() - 205,
          ),
        );
        return true;
      }
      if (call.method == 'navigate' && call.arguments is Map) {
        final arguments = (call.arguments as Map).cast<String, dynamic>();
        final route = ControlRoute.values.byName(
          arguments['route'] as String? ?? ControlRoute.timer.name,
        );
        onNavigate?.call(route, arguments['groupId'] as String?);
        await _resizeControlWindow(route);
        await windowManager.show();
        await windowManager.focus();
        return true;
      }
      if (call.method != 'stateSnapshot' || call.arguments is! String) {
        return null;
      }
      final envelope = WindowEnvelope.decode(call.arguments as String);
      onState(envelope.payload, envelope.revision);
      return true;
    });
    await sendCommand(WindowCommand.requestSnapshot);
  }

  Future<void> sendCommand(
    WindowCommand command, {
    Map<String, dynamic> arguments = const <String, dynamic>{},
    int revision = 0,
  }) async {
    final rootId = launchArguments.rootWindowId;
    if (rootId == null) return;
    final root = WindowController.fromWindowId(rootId);
    await root.invokeMethod<void>(
      'command',
      WindowEnvelope.command(
        command,
        revision: revision,
        arguments: arguments,
      ).encode(),
    );
  }

  Future<void> broadcastState(
    Map<String, dynamic> payload,
    int revision,
  ) async {
    if (_children.isEmpty) return;
    final envelope = WindowEnvelope(
      type: WindowMessageType.stateSnapshot,
      revision: revision,
      payload: payload,
    ).encode();
    final failed = <WindowController>[];
    for (final child in List<WindowController>.of(_children)) {
      try {
        await child.invokeMethod<void>('stateSnapshot', envelope);
      } on Object {
        failed.add(child);
      }
    }
    for (final child in failed) {
      _forgetChild(child.windowId);
    }
  }

  Future<void> openControlCenter(ControlRoute route, {String? groupId}) async {
    final existing = _windowForRoute(route);
    if (existing != null) {
      try {
        await existing.invokeMethod<void>('navigate', <String, dynamic>{
          'route': route.name,
          'groupId': groupId,
        });
        await existing.show();
        return;
      } on Object {
        _children.remove(existing);
        _setWindowForRoute(route, null);
      }
    }
    final controller = await _ensureControlWindow(route);
    if (groupId != null) {
      await controller.invokeMethod<void>('navigate', <String, dynamic>{
        'route': route.name,
        'groupId': groupId,
      });
    }
    await controller.show();
  }

  Future<void> prewarmControlCenter(ControlRoute route) async {
    if (_windowForRoute(route) != null) return;
    try {
      await _ensureControlWindow(route);
    } on Object catch (error, stack) {
      await CrashReporter.instance.record(
        error,
        stack,
        context: 'prewarm_control_center',
      );
    }
  }

  Future<WindowController> _ensureControlWindow(ControlRoute route) async {
    final existing = _windowForRoute(route);
    if (existing != null) return existing;
    if (route == ControlRoute.chat && _chatWindowCreation != null) {
      return _chatWindowCreation!;
    }

    final creation = _createControlWindow(route);
    if (route == ControlRoute.chat) _chatWindowCreation = creation;
    try {
      return await creation;
    } finally {
      if (route == ControlRoute.chat) _chatWindowCreation = null;
    }
  }

  Future<WindowController> _createControlWindow(ControlRoute route) async {
    final args = WindowLaunchArguments(
      role: WindowRole.controlCenter,
      route: route,
      rootWindowId: _currentWindow?.windowId,
    );
    final controller = await WindowController.create(
      WindowConfiguration(hiddenAtLaunch: true, arguments: args.encode()),
    );
    _setWindowForRoute(route, controller);
    _children.add(controller);
    return controller;
  }

  Future<void> showBubble() async {
    if (!usesSeparateBubbleWindow) return;
    final existing = _bubbleWindow;
    if (existing != null) {
      try {
        await existing.show();
        _scheduleBubblePosition(immediate: true);
        return;
      } on Object {
        _children.remove(existing);
        _bubbleWindow = null;
      }
    }
    final controller = await WindowController.create(
      WindowConfiguration(
        hiddenAtLaunch: true,
        arguments: WindowLaunchArguments(
          role: WindowRole.bubble,
          rootWindowId: _currentWindow?.windowId,
        ).encode(),
      ),
    );
    _bubbleWindow = controller;
    _children.add(controller);
    await controller.show();
    _scheduleBubblePosition(immediate: true);
  }

  Future<void> hideBubble() async => _bubbleWindow?.hide();

  Future<void> closeSecondaryWindows() async {
    final windows = <WindowController?>[
      _settingsWindow,
      _chatWindow,
      _leaderboardWindow,
      _bubbleWindow,
    ];
    for (final window in windows) {
      if (window == null) continue;
      try {
        await window.invokeMethod<void>('close');
      } on Object {
        // It may already have been closed with the native title-bar button.
      }
      _children.remove(window);
    }
    _settingsWindow = null;
    _chatWindow = null;
    _leaderboardWindow = null;
    _bubbleWindow = null;
  }

  Future<void> startPetDrag() async {
    final size = await windowManager.getSize();
    if (size.width < 200) await windowManager.setSize(const Size(224, 200));
    await windowManager.startDragging();
  }

  Future<bool> movePetStep(bool facingLeft) async {
    final position = await windowManager.getPosition();
    final size = await windowManager.getSize();
    if (size.width < 200) return facingLeft;
    final display = await _displayFor(position, size);
    final visiblePosition = display.visiblePosition ?? Offset.zero;
    final visibleSize = display.visibleSize ?? display.size;
    final minX = visiblePosition.dx + 30;
    final maxX = visiblePosition.dx + visibleSize.width - size.width - 30;
    var nextX = position.dx + (facingLeft ? -0.9 : 0.9);
    var nextFacingLeft = facingLeft;
    if (nextX <= minX) {
      nextX = minX;
      nextFacingLeft = false;
    } else if (nextX >= maxX) {
      nextX = maxX;
      nextFacingLeft = true;
    }
    await windowManager.setPosition(Offset(nextX, position.dy));
    return nextFacingLeft;
  }

  Future<void> performPetFlight(
    bool preferLeft, {
    ValueChanged<bool>? onDirectionResolved,
  }) async {
    final start = await windowManager.getPosition();
    final size = await windowManager.getSize();
    final display = await _displayFor(start, size);
    final origin = display.visiblePosition ?? Offset.zero;
    final visible = display.visibleSize ?? display.size;
    final minX = origin.dx + 30;
    final maxX = origin.dx + visible.width - size.width - 30;
    final leftAvailable = math.max(0.0, start.dx - minX);
    final rightAvailable = math.max(0.0, maxX - start.dx);
    var flyLeft = preferLeft;
    if (flyLeft && leftAvailable < 40 && rightAvailable > leftAvailable) {
      flyLeft = false;
    } else if (!flyLeft &&
        rightAvailable < 40 &&
        leftAvailable > rightAvailable) {
      flyLeft = true;
    }
    final available = flyLeft ? leftAvailable : rightAvailable;
    final travel = math.min(120.0, available);
    final horizontal = flyLeft ? -travel : travel;
    onDirectionResolved?.call(flyLeft);
    final stopwatch = Stopwatch()..start();
    const duration = Duration(milliseconds: 1600);
    while (stopwatch.elapsed < duration) {
      final t = stopwatch.elapsedMicroseconds / duration.inMicroseconds;
      final x = start.dx + horizontal * t;
      final y = start.dy - 4 * size.height * t * (1 - t);
      await windowManager.setPosition(Offset(x, y));
      await Future<void>.delayed(
        Duration(milliseconds: Platform.isWindows ? 33 : 16),
      );
    }
    await windowManager.setPosition(Offset(start.dx + horizontal, start.dy));
  }

  Future<({Offset position, PetDockSide? dockSide})> settlePetWindow(
    bool obedient,
  ) async {
    var position = await windowManager.getPosition();
    var size = await windowManager.getSize();
    final display = await _displayFor(position, size);
    final visiblePosition = display.visiblePosition ?? Offset.zero;
    final visibleSize = display.visibleSize ?? display.size;
    final visibleRight = visiblePosition.dx + visibleSize.width;
    PetDockSide? side;
    if (obedient) {
      final spriteLeft = position.dx + 28;
      final spriteRight = spriteLeft + 108;
      if (spriteLeft <= visiblePosition.dx + 32) {
        side = PetDockSide.left;
        position = Offset(visiblePosition.dx - 28, position.dy);
      } else if (spriteRight >= visibleRight - 32) {
        side = PetDockSide.right;
        position = Offset(visibleRight - 108 - 28, position.dy);
      }
    }
    if (side != null) {
      size = const Size(164, 200);
      await windowManager.setSize(size);
    } else if (size.width < 200) {
      size = const Size(224, 200);
      await windowManager.setSize(size);
    }
    final maxY = visiblePosition.dy + visibleSize.height - size.height;
    position = Offset(position.dx, position.dy.clamp(visiblePosition.dy, maxY));
    await windowManager.setPosition(position, animate: side != null);
    return (position: position, dockSide: side);
  }

  Future<Offset> dockPetWindow(PetDockSide side) async {
    var position = await windowManager.getPosition();
    final currentSize = await windowManager.getSize();
    final display = await _displayFor(position, currentSize);
    final visiblePosition = display.visiblePosition ?? Offset.zero;
    final visibleSize = display.visibleSize ?? display.size;
    const dockedSize = Size(164, 200);
    position = calculateDockedPetPosition(
      visiblePosition: visiblePosition,
      visibleSize: visibleSize,
      currentY: position.dy,
      side: side,
    );
    await windowManager.setSize(dockedSize);
    await windowManager.setPosition(position, animate: true);
    return position;
  }

  Future<Offset> revealPetWindow() async {
    var position = await windowManager.getPosition();
    final currentSize = await windowManager.getSize();
    final display = await _displayFor(position, currentSize);
    final visiblePosition = display.visiblePosition ?? Offset.zero;
    final visibleSize = display.visibleSize ?? display.size;
    const fullSize = Size(224, 200);
    position = Offset(
      position.dx.clamp(
        visiblePosition.dx + 30,
        visiblePosition.dx + visibleSize.width - fullSize.width - 30,
      ),
      position.dy.clamp(
        visiblePosition.dy,
        visiblePosition.dy + visibleSize.height - fullSize.height,
      ),
    );
    await windowManager.setSize(fullSize);
    await windowManager.setPosition(position, animate: true);
    return position;
  }

  Future<void> restorePetPosition(double? x, double? y) async {
    if (x == null || y == null) return;
    final size = await windowManager.getSize();
    final desired = Offset(x, y);
    final display = await _displayFor(desired, size);
    final origin = display.visiblePosition ?? Offset.zero;
    final bounds = display.visibleSize ?? display.size;
    await windowManager.setPosition(
      Offset(
        desired.dx.clamp(origin.dx, origin.dx + bounds.width - size.width),
        desired.dy.clamp(origin.dy, origin.dy + bounds.height - size.height),
      ),
    );
  }

  Future<void> setOnboardingMode(bool onboarding) async {
    if (Platform.isMacOS) {
      await const MethodChannel('ass_timer/desktop_host').invokeMethod<void>(
        'setActivationPolicy',
        onboarding ? 'regular' : 'accessory',
      );
    }
    if (onboarding) {
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setSkipTaskbar(false);
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      await windowManager.setResizable(false);
      await windowManager.setSize(const Size(680, 365));
      await windowManager.center();
      await windowManager.show();
      await windowManager.focus();
    } else {
      await windowManager.setSize(const Size(224, 200));
      await windowManager.setResizable(false);
      await windowManager.setAsFrameless();
      await windowManager.setSkipTaskbar(!Platform.isWindows || _trayAvailable);
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setVisibleOnAllWorkspaces(
        true,
        visibleOnFullScreen: true,
      );
    }
  }

  Stream<String> get powerEvents => Platform.isWindows
      ? _windowsPowerEvents.stream
      : const EventChannel('ass_timer/power_events')
          .receiveBroadcastStream()
          .where((event) => event is String)
          .cast<String>();

  Future<void> quit() async {
    if (Platform.isWindows && _trayAvailable) await trayManager.destroy();
    await windowManager.destroy();
  }

  Future<void> updateControlWindowRoute(ControlRoute route) =>
      _resizeControlWindow(route);

  @override
  void onWindowMoved() {
    if (launchArguments.role != WindowRole.pet) return;
    _moveSettledTimer?.cancel();
    _moveSettledTimer = Timer(const Duration(milliseconds: 180), () {
      onPetMoveSettled?.call();
    });
    _scheduleBubblePosition();
  }

  @override
  void onWindowClose() {
    unawaited(_handleCurrentWindowClosed());
  }

  Future<Display> _displayFor(Offset position, Size size) async {
    final center = position + Offset(size.width / 2, size.height / 2);
    final displays = await screenRetriever.getAllDisplays();
    for (final display in displays) {
      final origin = display.visiblePosition ?? Offset.zero;
      final visible = display.visibleSize ?? display.size;
      if ((origin & visible).contains(center)) return display;
    }
    return screenRetriever.getPrimaryDisplay();
  }

  void _scheduleBubblePosition({bool immediate = false}) {
    if (launchArguments.role != WindowRole.pet) return;
    _bubbleAnchorThrottle.schedule(
      _positionBubbleNearPet,
      immediate: immediate,
    );
  }

  Future<void> _positionBubbleNearPet() async {
    final bubble = _bubbleWindow;
    if (bubble == null || launchArguments.role != WindowRole.pet) return;
    final position = await windowManager.getPosition();
    try {
      await bubble.invokeMethod<void>('anchor', <String, double>{
        'x': position.dx,
        'y': position.dy,
      });
    } on Object {
      // A newly-created secondary engine may not have registered yet.
    }
  }

  Future<void> _handleCurrentWindowClosed() async {
    final current = _currentWindow;
    final rootId = launchArguments.rootWindowId;
    if (launchArguments.role != WindowRole.pet &&
        current != null &&
        rootId != null) {
      try {
        await WindowController.fromWindowId(
          rootId,
        ).invokeMethod<void>('childClosed', current.windowId);
      } on Object catch (error, stack) {
        await CrashReporter.instance.record(
          error,
          stack,
          context: 'notify_child_closed',
        );
      }
    }
    await disposeCurrentWindow();
  }

  void _forgetChild(String windowId) {
    _children.removeWhere((window) => window.windowId == windowId);
    if (_settingsWindow?.windowId == windowId) _settingsWindow = null;
    if (_chatWindow?.windowId == windowId) _chatWindow = null;
    if (_leaderboardWindow?.windowId == windowId) _leaderboardWindow = null;
    if (_bubbleWindow?.windowId == windowId) _bubbleWindow = null;
  }

  Future<void> disposeCurrentWindow() async {
    if (_disposed) return;
    _disposed = true;
    _moveSettledTimer?.cancel();
    _bubbleAnchorThrottle.dispose();
    windowManager.removeListener(this);
    await _currentWindow?.setWindowMethodHandler(null);
    if (Platform.isWindows && launchArguments.role == WindowRole.pet) {
      const MethodChannel(
        'ass_timer/power_events_windows',
      ).setMethodCallHandler(null);
      trayManager.removeListener(this);
    }
    await _windowsPowerEvents.close();
  }

  Future<void> _initializeWindowsTray() async {
    trayManager.addListener(this);
    onTrayTogglePet ??= () {
      unawaited(_toggleCurrentWindow());
    };
    final executableDirectory = File(Platform.resolvedExecutable).parent.path;
    final iconPath = p.join(
      executableDirectory,
      'data',
      'flutter_assets',
      'assets',
      'tray',
      'tray_icon.ico',
    );
    await trayManager.setIcon(iconPath);
    await trayManager.setToolTip('Ass-Timer');
    await trayManager.setContextMenu(
      Menu(
        items: <MenuItem>[
          MenuItem(key: 'toggle_pet', label: '显示/隐藏宠物'),
          MenuItem(key: 'open_control', label: '打开控制中心'),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: '退出'),
        ],
      ),
    );
  }

  Future<void> _toggleCurrentWindow() async {
    if (await windowManager.isVisible()) {
      await windowManager.hide();
    } else {
      await windowManager.show();
    }
  }

  static Size _controlSizeFor(ControlRoute route) => switch (route) {
        ControlRoute.chat => const Size(620, 440),
        ControlRoute.leaderboard => const Size(320, 420),
        ControlRoute.timer ||
        ControlRoute.groups ||
        ControlRoute.media ||
        ControlRoute.about =>
          const Size(420, 468),
      };

  Future<void> _resizeControlWindow(ControlRoute route) async {
    if (launchArguments.role != WindowRole.controlCenter) return;
    final title = switch (route) {
      ControlRoute.timer ||
      ControlRoute.groups ||
      ControlRoute.media ||
      ControlRoute.about =>
        '设置',
      ControlRoute.chat => '群聊',
      ControlRoute.leaderboard => '排行榜',
    };
    final settingsRoute = route == ControlRoute.timer ||
        route == ControlRoute.groups ||
        route == ControlRoute.media ||
        route == ControlRoute.about;
    await windowManager.setTitle(settingsRoute ? '' : title);
    await windowManager.setTitleBarStyle(
      settingsRoute ? TitleBarStyle.hidden : TitleBarStyle.normal,
    );
    await windowManager.setMinimumSize(
      route == ControlRoute.chat
          ? const Size(560, 380)
          : _controlSizeFor(route),
    );
    await windowManager.setResizable(route == ControlRoute.chat);
    await windowManager.setSize(_controlSizeFor(route), animate: true);
  }

  WindowController? _windowForRoute(ControlRoute route) => switch (route) {
        ControlRoute.chat => _chatWindow,
        ControlRoute.leaderboard => _leaderboardWindow,
        ControlRoute.timer ||
        ControlRoute.groups ||
        ControlRoute.media ||
        ControlRoute.about =>
          _settingsWindow,
      };

  void _setWindowForRoute(ControlRoute route, WindowController? window) {
    switch (route) {
      case ControlRoute.chat:
        _chatWindow = window;
      case ControlRoute.leaderboard:
        _leaderboardWindow = window;
      case ControlRoute.timer:
      case ControlRoute.groups:
      case ControlRoute.media:
      case ControlRoute.about:
        _settingsWindow = window;
    }
  }

  @override
  void onTrayIconMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'toggle_pet':
        onTrayTogglePet?.call();
      case 'open_control':
        openControlCenter(ControlRoute.timer);
      case 'quit':
        onTrayQuit?.call();
        quit();
    }
  }
}
