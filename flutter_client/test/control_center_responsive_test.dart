import 'package:ass_timer_flutter/application/app_controller.dart';
import 'package:ass_timer_flutter/core/theme/app_theme.dart';
import 'package:ass_timer_flutter/data/api_client.dart';
import 'package:ass_timer_flutter/data/api_models.dart';
import 'package:ass_timer_flutter/data/app_store.dart';
import 'package:ass_timer_flutter/domain/app_models.dart';
import 'package:ass_timer_flutter/features/control_center/control_center_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  const settingsRoutes = <ControlRoute>[
    ControlRoute.timer,
    ControlRoute.groups,
    ControlRoute.media,
    ControlRoute.about,
  ];
  for (final route in settingsRoutes) {
    testWidgets('${route.name} fits the minimum window at 1.5 text scaling',
        (tester) async {
      await _pumpRoute(tester, route, const Size(440, 500));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('chat handles a long group name and long message',
      (tester) async {
    await _pumpRoute(tester, ControlRoute.chat, const Size(620, 440));
    expect(find.textContaining('这是一个很长'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('join form keeps submission errors beside the form',
      (tester) async {
    final controller =
        await _pumpRoute(tester, ControlRoute.groups, const Size(440, 500));
    await tester.tap(find.widgetWithText(OutlinedButton, '加入群组'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ab12c3');
    await tester.tap(find.widgetWithText(FilledButton, '加入'));
    await tester.pumpAndSettle();

    expect(controller.joinedCode, 'AB12C3');
    expect(find.text('邀请码没对上，再看一眼。'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaderboard fits the minimum standalone window', (tester) async {
    await _pumpRoute(tester, ControlRoute.leaderboard, const Size(340, 420));
    expect(find.text('排行榜'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<_FakeController> _pumpRoute(
  WidgetTester tester,
  ControlRoute route,
  Size size,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = 1.5;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  final controller = _FakeController(route);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appControllerProvider.overrideWith((ref) => controller),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const ControlCenterView(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

class _FakeController extends AppController {
  _FakeController(ControlRoute route)
      : super(store: AppStore(), apiClient: ApiClient()) {
    const joinedGroup = JoinedGroup(
      groupId: 'group-1',
      groupName: '这是一个很长很长但仍然需要正常显示的群组名称',
      inviteCode: 'A1B2C3',
    );
    controlRoute = route;
    activeChatGroupId = 'group-1';
    snapshot = AppSnapshot.initial().copyWith(
      config: const UserConfig(
        userId: 'me',
        nickname: '测试用户',
        joinedGroups: <JoinedGroup>[joinedGroup],
        localEventCount: 42,
        onboardingComplete: true,
      ),
      unreadCounts: const <String, int>{'group-1': 12},
    );
    groups = const <GroupInfo>[
      GroupInfo(
        groupId: 'group-1',
        name: '这是一个很长很长但仍然需要正常显示的群组名称',
        inviteCode: 'A1B2C3',
        members: <GroupMember>[
          GroupMember(
            userId: 'me',
            nickname: '测试用户',
            petEmoji: '🦌',
            avatarUrl: '',
          ),
        ],
      ),
    ];
    leaderboard = const <LeaderboardEntry>[
      LeaderboardEntry(
        rank: 1,
        userId: 'me',
        nickname: '测试用户',
        petEmoji: '🦌',
        avatarUrl: '',
        count: 42,
      ),
    ];
    chatMessages['group-1'] = <ChatMessage>[
      ChatMessage(
        sequence: 1,
        messageId: 'message-1',
        groupId: 'group-1',
        userId: 'friend',
        nickname: '群友',
        petEmoji: '🦌',
        avatarUrl: '',
        content: '这是一段很长的聊天文本，用来确认窗口缩放时消息气泡仍然会正常换行，不会把布局撑坏。',
        createdAt: DateTime(2026, 7, 20, 9),
      ),
    ];
  }

  String? joinedCode;

  @override
  Future<void> initialize() async {
    isReady = true;
  }

  @override
  Future<void> refreshGroups() async {}

  @override
  Future<void> refreshLeaderboard(String groupId) async {}

  @override
  Future<void> loadChat(String groupId) async {}

  @override
  Future<void> joinGroup(String code) async {
    joinedCode = code;
    snapshot = snapshot.copyWith(lastError: '邀请码没对上，再看一眼。');
    notifyListeners();
    throw StateError('test join error');
  }
}
