import 'dart:async';
import 'dart:ui';

import 'package:ass_timer_flutter/application/app_controller.dart';
import 'package:ass_timer_flutter/core/diagnostics/crash_reporter.dart';
import 'package:ass_timer_flutter/core/theme/app_theme.dart';
import 'package:ass_timer_flutter/core/window/desktop_host.dart';
import 'package:ass_timer_flutter/core/window/window_protocol.dart';
import 'package:ass_timer_flutter/domain/app_models.dart';
import 'package:ass_timer_flutter/features/bubble/bubble_window_view.dart';
import 'package:ass_timer_flutter/features/control_center/control_center_view.dart';
import 'package:ass_timer_flutter/features/onboarding/onboarding_view.dart';
import 'package:ass_timer_flutter/features/pet/pet_window_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await CrashReporter.instance.initialize();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    CrashReporter.instance.recordSync(
      details.exception,
      details.stack ?? StackTrace.current,
      context: details.context?.toDescription() ?? 'flutter_error',
      fatal: true,
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    CrashReporter.instance.recordSync(
      error,
      stack,
      context: 'platform_dispatcher',
      fatal: true,
    );
    return true;
  };
  await runZonedGuarded<Future<void>>(
    () async {
      final startup = await DesktopHost.instance.initializeCurrentWindow();
      runApp(
        ProviderScope(
          overrides: [
            launchArgumentsProvider.overrideWithValue(startup.launchArguments),
          ],
          child: AssTimerApp(launch: startup.launchArguments),
        ),
      );
    },
    (error, stack) => CrashReporter.instance.recordSync(
      error,
      stack,
      context: 'root_zone',
      fatal: true,
    ),
  );
}

class AssTimerApp extends StatelessWidget {
  const AssTimerApp({required this.launch, super.key});

  final WindowLaunchArguments launch;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '该提肛了',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
          countryCode: 'CN',
        ),
        supportedLocales: const <Locale>[
          Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hans',
            countryCode: 'CN',
          ),
        ],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: switch (launch.role) {
          WindowRole.pet => const _RootWindow(),
          WindowRole.bubble => const BubbleWindowView(),
          WindowRole.controlCenter =>
            ControlCenterView(initialRoute: launch.route),
        },
      );
}

class _RootWindow extends ConsumerStatefulWidget {
  const _RootWindow();

  @override
  ConsumerState<_RootWindow> createState() => _RootWindowState();
}

class _RootWindowState extends ConsumerState<_RootWindow>
    with WidgetsBindingObserver {
  bool? _lastOnboarding;
  bool _bubbleVisible = false;
  StreamSubscription<String>? _powerSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _powerSubscription = DesktopHost.instance.powerEvents.listen((event) {
      if (event == 'wake') {
        unawaited(ref.read(appControllerProvider).handleWake());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_powerSubscription?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(appControllerProvider).handleWake());
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    if (!controller.isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final needsOnboarding = !controller.snapshot.config.hasCompletedOnboarding;
    if (_lastOnboarding != needsOnboarding) {
      _lastOnboarding = needsOnboarding;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(() async {
          await DesktopHost.instance.setOnboardingMode(needsOnboarding);
          if (!needsOnboarding) {
            await DesktopHost.instance.restorePetPosition(
              controller.snapshot.config.windowOriginX,
              controller.snapshot.config.windowOriginY,
            );
            await controller.ensureObedientDocked();
          }
        }());
      });
    }
    final hasBubble = controller.snapshot.bubbles.isNotEmpty;
    if (_bubbleVisible != hasBubble) {
      _bubbleVisible = hasBubble;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(
          hasBubble
              ? DesktopHost.instance.showBubble()
              : DesktopHost.instance.hideBubble(),
        );
      });
    }
    return needsOnboarding ? const OnboardingView() : const PetWindowView();
  }
}
