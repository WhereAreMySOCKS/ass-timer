import 'dart:async';

import 'package:ass_timer_flutter/core/diagnostics/crash_reporter.dart';
import 'package:ass_timer_flutter/core/window/desktop_host.dart';
import 'package:ass_timer_flutter/core/window/window_protocol.dart';
import 'package:ass_timer_flutter/data/api_client.dart';
import 'package:ass_timer_flutter/data/api_models.dart';
import 'package:ass_timer_flutter/data/app_store.dart';
import 'package:ass_timer_flutter/data/chat_cache.dart';
import 'package:ass_timer_flutter/data/custom_media_service.dart';
import 'package:ass_timer_flutter/data/web_socket_service.dart';
import 'package:ass_timer_flutter/domain/app_models.dart';
import 'package:ass_timer_flutter/domain/bubble_queue.dart';
import 'package:ass_timer_flutter/domain/pet_activity_engine.dart';
import 'package:ass_timer_flutter/domain/timer_engine.dart';
import 'package:ass_timer_flutter/domain/version_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

final appStoreProvider = Provider<AppStore>((ref) => AppStore());
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
final launchArgumentsProvider = Provider<WindowLaunchArguments>(
  (ref) => const WindowLaunchArguments(role: WindowRole.pet),
);

final appControllerProvider = ChangeNotifierProvider<AppController>((ref) {
  final launch = ref.watch(launchArgumentsProvider);
  final controller = launch.role == WindowRole.pet
      ? AppController(
          store: ref.watch(appStoreProvider),
          apiClient: ref.watch(apiClientProvider),
        )
      : ReplicaAppController(
          launch: launch,
          store: ref.watch(appStoreProvider),
          apiClient: ref.watch(apiClientProvider),
        );
  unawaited(controller.initialize());
  ref.onDispose(controller.dispose);
  return controller;
});

class AppController extends ChangeNotifier {
  AppController({required AppStore store, required ApiClient apiClient})
      : _store = store,
        _apiClient = apiClient,
        _chatCache = ChatCache(store),
        _customMedia = CustomMediaService(store) {
    _timer = TimerEngine(
      onChanged: _onTimerChanged,
      onFire: _onTimerFire,
    );
    _bubbles = BubbleQueue(onChanged: _onBubblesChanged);
    _activity = PetActivityEngine(onChanged: _onPetActivityChanged);
    _webSocket = WebSocketService(
      onEvent: _onServerEvent,
      onConnectionStateChanged: _onBackendConnectionStateChanged,
      onMalformedMessage: (error, stack) {
        unawaited(
          CrashReporter.instance.record(
            error,
            stack,
            context: 'websocket_message',
          ),
        );
      },
    );
  }

  final AppStore _store;
  final ApiClient _apiClient;
  final ChatCache _chatCache;
  final CustomMediaService _customMedia;
  late final TimerEngine _timer;
  late final BubbleQueue _bubbles;
  late final PetActivityEngine _activity;
  late final WebSocketService _webSocket;
  Timer? _updateCheckTimer;
  Timer? _interactionTimer;
  String? _activitySprite;
  bool _isChangingObedientMode = false;

  AppSnapshot snapshot = AppSnapshot.initial();
  bool isReady = false;
  bool isBusy = false;
  bool supportsBackgroundRemoval = false;
  BackendConnectionState backendConnectionState =
      BackendConnectionState.disconnected;
  ControlRoute controlRoute = ControlRoute.timer;
  String? activeChatGroupId;
  AppVersionInfo? availableUpdate;
  List<GroupInfo> groups = <GroupInfo>[];
  List<LeaderboardEntry> leaderboard = <LeaderboardEntry>[];
  final Map<String, List<ChatMessage>> chatMessages =
      <String, List<ChatMessage>>{};

  String get exerciseName =>
      snapshot.config.appMode == AppMode.obedient ? '放松' : '提肛';
  String get reminderTitle =>
      snapshot.config.appMode == AppMode.obedient ? '该放松了！' : '该提肛了！';
  String get completionTitle =>
      snapshot.config.appMode == AppMode.obedient ? '已放松' : '已提';
  bool get isPetMoving => _activity.isMoving;

  Future<void> initialize() async {
    if (isReady) return;
    await DesktopHost.instance.bindRoot(_handleWindowCommand);
    final config = await _store.loadConfig();
    final nextReminderAt = await _store.loadNextReminderAt();
    supportsBackgroundRemoval = await _customMedia.supportsBackgroundRemoval();
    snapshot = snapshot.copyWith(config: config);
    isReady = true;
    notifyListeners();

    if (config.hasCompletedOnboarding) {
      _startSession(nextReminderAt);
    }
  }

  Future<void> createProfile(String nickname, String avatarPath) async {
    await _guardBusy(() async {
      final profile = await _apiClient.createUser(
        nickname: nickname.trim(),
        avatarPath: avatarPath,
      );
      _update(
          config: profile.copyWith(
              intervalSeconds: snapshot.config.intervalSeconds));
      await _store.saveConfig(snapshot.config);
    });
  }

  Future<void> createGroup(String name) async {
    final userId = snapshot.config.userId;
    if (userId == null) return;
    await _guardBusy(() async {
      final group = await _apiClient.createGroup(userId, name.trim());
      await _saveGroups(<JoinedGroup>[...snapshot.config.joinedGroups, group]);
    });
  }

  Future<void> joinGroup(String code) async {
    final userId = snapshot.config.userId;
    if (userId == null) return;
    await _guardBusy(() async {
      final group = await _apiClient.joinGroup(userId, code.trim());
      if (!snapshot.config.joinedGroups
          .any((candidate) => candidate.groupId == group.groupId)) {
        await _saveGroups(
            <JoinedGroup>[...snapshot.config.joinedGroups, group]);
      }
    });
  }

  Future<void> leaveGroup(String groupId) async {
    final userId = snapshot.config.userId;
    if (userId == null) return;
    await _guardBusy(() async {
      await _apiClient.leaveGroup(userId, groupId);
      await _saveGroups(
        snapshot.config.joinedGroups
            .where((group) => group.groupId != groupId)
            .toList(growable: false),
      );
      groups.removeWhere((group) => group.groupId == groupId);
    });
  }

  Future<void> completeOnboarding(int intervalSeconds) async {
    final config = snapshot.config.copyWith(
      intervalSeconds: TimerEngine.normalizeInterval(intervalSeconds),
      onboardingComplete: true,
      petImageName: 'pet_deer',
    );
    _update(config: config);
    await _store.saveConfig(config);
    _startSession(null);
  }

  Future<void> clearLocalData() async {
    final userId = snapshot.config.userId;
    await _webSocket.disconnect();
    _timer.stopTicker();
    _activity.stop();
    _bubbles.clear();
    _updateCheckTimer?.cancel();
    if (userId != null) {
      try {
        await _apiClient.deleteUser(userId);
      } on Object {
        // Local reset remains available while offline. The server may retain an
        // orphaned account, but no local identity or credentials are kept.
      }
    }
    await _store.clearLocalState();
    groups = <GroupInfo>[];
    leaderboard = <LeaderboardEntry>[];
    chatMessages.clear();
    activeChatGroupId = null;
    availableUpdate = null;
    backendConnectionState = BackendConnectionState.disconnected;
    snapshot = AppSnapshot.initial().copyWith(
      revision: snapshot.revision + 1,
    );
    notifyListeners();
    await DesktopHost.instance.closeSecondaryWindows();
  }

  Future<void> modifyInterval(int seconds) async {
    final normalized = TimerEngine.normalizeInterval(seconds);
    final config = snapshot.config.copyWith(intervalSeconds: normalized);
    _update(config: config);
    await _store.saveConfig(config);
    _timer.reset(intervalSeconds: normalized);
  }

  Future<void> completeReminder() async {
    if (snapshot.timerPhase != TimerPhase.reminder) return;
    _bubbles.removeKind(BubbleKind.reminder);
    _timer.complete(intervalSeconds: snapshot.config.intervalSeconds);

    final config = snapshot.config.copyWith(
      localEventCount: snapshot.config.localEventCount + 1,
    );
    _update(config: config, currentSprite: '得意');
    await _store.saveConfig(config);

    final userId = config.userId;
    if (userId != null) {
      unawaited(
        _apiClient
            .logEvent(
              userId,
              config.joinedGroups.map((group) => group.groupId).toList(),
            )
            .catchError((Object error) => _showError('无法连接后端，已记录本地')),
      );
    }
  }

  void skipReminder() {
    _bubbles.removeKind(BubbleKind.reminder);
    _timer.skip(intervalSeconds: snapshot.config.intervalSeconds);
  }

  Future<void> toggleObedientMode() async {
    if (_isChangingObedientMode) return;
    _isChangingObedientMode = true;
    final entering = snapshot.config.appMode != AppMode.obedient;
    try {
      if (entering) {
        _activity.stop();
        final enteringConfig = snapshot.config.copyWith(
          appMode: AppMode.obedient,
        );
        _update(
          config: enteringConfig,
          currentSprite: '后视镜',
          dockSide: PetDockSide.left,
        );
        final position =
            await DesktopHost.instance.dockPetWindow(PetDockSide.left);
        final config = enteringConfig.copyWith(
          windowOriginX: position.dx,
          windowOriginY: position.dy,
        );
        _update(
          config: config,
          currentSprite: '后视镜',
          dockSide: PetDockSide.left,
        );
        await _store.saveConfig(config);
      } else {
        final position = await DesktopHost.instance.revealPetWindow();
        final config = snapshot.config.copyWith(
          appMode: AppMode.normal,
          windowOriginX: position.dx,
          windowOriginY: position.dy,
        );
        _update(
          config: config,
          currentSprite: '起飞',
          clearDockSide: true,
        );
        _activity.fly();
        await DesktopHost.instance.performPetFlight(
          snapshot.petFacingLeft,
          onDirectionResolved: setPetFacingLeft,
        );
        _activity.start();
        final landed = await DesktopHost.instance.revealPetWindow();
        final landedConfig = config.copyWith(
          windowOriginX: landed.dx,
          windowOriginY: landed.dy,
        );
        _update(config: landedConfig, clearDockSide: true);
        await _store.saveConfig(landedConfig);
      }
    } finally {
      _isChangingObedientMode = false;
    }
  }

  void interact() {
    final sprite = snapshot.config.appMode == AppMode.obedient ? '得意' : '愤怒';
    _interactionTimer?.cancel();
    _update(currentSprite: sprite);
    _interactionTimer = Timer(
      snapshot.config.appMode == AppMode.obedient
          ? const Duration(milliseconds: 100)
          : const Duration(seconds: 2),
      () {
        if (snapshot.currentSprite == sprite) {
          final fallback = _activitySprite;
          _update(
            currentSprite: fallback,
            clearCurrentSprite: fallback == null,
          );
        }
        _interactionTimer = null;
      },
    );
  }

  void _cancelInteractionSprite() {
    _interactionTimer?.cancel();
    _interactionTimer = null;
    if (snapshot.currentSprite == '愤怒' || snapshot.currentSprite == '得意') {
      _update(
        currentSprite: _activitySprite,
        clearCurrentSprite: _activitySprite == null,
      );
    }
  }

  bool get _isShowingInteractionSprite => _interactionTimer?.isActive ?? false;

  void _showActivitySprite(
    PetActivityPhase phase,
    String sprite,
    bool facingLeft,
  ) {
    _activitySprite = sprite;
    _update(
      petActivityPhase: phase,
      currentSprite: _isShowingInteractionSprite ? null : sprite,
      petFacingLeft: facingLeft,
    );
  }

  void fly() {
    if (snapshot.config.appMode != AppMode.obedient) {
      _cancelInteractionSprite();
      _activity.fly();
    }
  }

  void setPetFacingLeft(bool value) => _update(petFacingLeft: value);

  Future<void> settlePetWindow() async {
    if (_isChangingObedientMode) return;
    final settled = await DesktopHost.instance.settlePetWindow(
      snapshot.config.appMode == AppMode.obedient,
    );
    final config = snapshot.config.copyWith(
      windowOriginX: settled.position.dx,
      windowOriginY: settled.position.dy,
    );
    _update(
      config: config,
      dockSide: settled.dockSide,
      clearDockSide: settled.dockSide == null,
    );
    await _store.saveConfig(config);
  }

  Future<void> ensureObedientDocked() async {
    if (snapshot.config.appMode != AppMode.obedient) return;
    _activity.stop();
    final position = await DesktopHost.instance.dockPetWindow(PetDockSide.left);
    final config = snapshot.config.copyWith(
      windowOriginX: position.dx,
      windowOriginY: position.dy,
    );
    _update(
      config: config,
      currentSprite: '后视镜',
      dockSide: PetDockSide.left,
    );
    await _store.saveConfig(config);
  }

  Future<void> handleWake() async {
    _timer.handleWake(intervalSeconds: snapshot.config.intervalSeconds);
    final userId = snapshot.config.userId;
    if (userId != null) await _webSocket.connect(userId);
    await checkForUpdate(silent: true);
  }

  Future<void> refreshGroups() async {
    final userId = snapshot.config.userId;
    if (userId == null) return;
    try {
      groups = await _apiClient.getUserGroups(userId);
      notifyListeners();
    } on Object {
      _showError('群组信息加载失败，请重试');
    }
  }

  Future<void> refreshLeaderboard(String groupId) async {
    try {
      leaderboard = await _apiClient.getLeaderboard(groupId);
      notifyListeners();
    } on Object {
      _showError('排行榜加载失败，请重试');
    }
  }

  Future<void> loadChat(String groupId) async {
    activeChatGroupId = groupId;
    final cached = await _chatCache.load(groupId);
    chatMessages[groupId] = cached;
    _markChatRead(groupId);
    notifyListeners();
    try {
      final history = await _apiClient.getChatHistory(groupId);
      chatMessages[groupId] = await _chatCache.merge(groupId, history.messages);
      notifyListeners();
    } on Object {
      if (cached.isEmpty) _showError('聊天记录加载失败，请重试');
    }
  }

  Future<void> sendChat(String groupId, String content) async {
    final userId = snapshot.config.userId;
    final normalized = content.trim();
    if (userId == null || normalized.isEmpty || normalized.length > 2000) {
      return;
    }
    try {
      final message =
          await _apiClient.sendChatMessage(groupId, userId, normalized);
      chatMessages[groupId] =
          await _chatCache.merge(groupId, <ChatMessage>[message]);
      notifyListeners();
    } on Object {
      _showError('消息发送失败，请重试');
    }
  }

  void selectControlRoute(ControlRoute route, {String? groupId}) {
    controlRoute = route;
    if (groupId != null) unawaited(loadChat(groupId));
    notifyListeners();
  }

  Future<void> openControlCenter(
    ControlRoute route, {
    String? groupId,
  }) async {
    controlRoute = route;
    if (route != ControlRoute.chat) {
      activeChatGroupId = null;
    } else if (groupId != null) {
      await loadChat(groupId);
    }
    notifyListeners();
    await DesktopHost.instance.openControlCenter(route, groupId: groupId);
  }

  Future<void> checkForUpdate({bool silent = false}) async {
    try {
      final candidate = await _apiClient.getVersion();
      final current = (await PackageInfo.fromPlatform()).version;
      availableUpdate =
          VersionUtils.compare(candidate.latestVersion, current) > 0
              ? candidate
              : null;
      notifyListeners();
    } on Object {
      if (!silent) _showError('检查更新失败，请稍后重试');
    }
  }

  Future<void> saveCustomMedia(String slot, String sourcePath) async {
    try {
      final media = Map<String, CustomActionMediaEntry>.of(
        snapshot.config.customActionMedia,
      );
      media[slot] = await _customMedia.importImage(
        slot,
        sourcePath,
        replacing: media[slot],
      );
      final config = snapshot.config.copyWith(customActionMedia: media);
      _update(config: config);
      await _store.saveConfig(config);
    } on Object {
      _showError('图片处理失败，请选择 PNG、JPG 或 WebP 文件重试');
      rethrow;
    }
  }

  Future<void> removeCustomMedia(String slot) async {
    final media = Map<String, CustomActionMediaEntry>.of(
      snapshot.config.customActionMedia,
    );
    final entry = media.remove(slot);
    if (entry != null) await _customMedia.remove(entry);
    final config = snapshot.config.copyWith(customActionMedia: media);
    _update(config: config);
    await _store.saveConfig(config);
  }

  Future<void> setBackgroundRemoval(String slot, bool enabled) async {
    final media = Map<String, CustomActionMediaEntry>.of(
      snapshot.config.customActionMedia,
    );
    final entry = media[slot];
    if (entry == null) return;
    try {
      media[slot] = await _customMedia.setBackgroundRemoval(entry, enabled);
      final config = snapshot.config.copyWith(customActionMedia: media);
      _update(config: config);
      await _store.saveConfig(config);
    } on Object {
      _showError('没有识别到清晰的前景主体，或当前系统不支持去背景');
      rethrow;
    }
  }

  Future<dynamic> _handleWindowCommand(WindowEnvelope envelope) async {
    if (envelope.type != WindowMessageType.command) return null;
    final commandName = envelope.payload['command'] as String?;
    if (commandName == null) return null;
    final rawArguments = envelope.payload['arguments'];
    final arguments = rawArguments is Map
        ? rawArguments.cast<String, dynamic>()
        : const <String, dynamic>{};
    switch (WindowCommand.values.byName(commandName)) {
      case WindowCommand.requestSnapshot:
        _broadcastWindowState();
      case WindowCommand.completeReminder:
        await completeReminder();
      case WindowCommand.skipReminder:
        skipReminder();
      case WindowCommand.openControlCenter:
        await openControlCenter(
          ControlRoute.values.byName(
            arguments['route'] as String? ?? ControlRoute.timer.name,
          ),
          groupId: arguments['groupId'] as String?,
        );
      case WindowCommand.closeControlCenter:
        break;
      case WindowCommand.modifyInterval:
        await modifyInterval((arguments['seconds'] as num).toInt());
      case WindowCommand.toggleObedientMode:
        await toggleObedientMode();
      case WindowCommand.markChatRead:
        final groupId = arguments['groupId'] as String?;
        if (groupId != null) _markChatRead(groupId);
      case WindowCommand.refreshGroups:
        await refreshGroups();
      case WindowCommand.refreshLeaderboard:
        await refreshLeaderboard(arguments['groupId'] as String);
      case WindowCommand.loadChat:
        await loadChat(arguments['groupId'] as String);
      case WindowCommand.sendChat:
        await sendChat(
          arguments['groupId'] as String,
          arguments['content'] as String,
        );
      case WindowCommand.createGroup:
        await createGroup(arguments['name'] as String);
      case WindowCommand.joinGroup:
        await joinGroup(arguments['code'] as String);
      case WindowCommand.leaveGroup:
        await leaveGroup(arguments['groupId'] as String);
      case WindowCommand.checkForUpdate:
        await checkForUpdate();
      case WindowCommand.saveCustomMedia:
        await saveCustomMedia(
          arguments['slot'] as String,
          arguments['sourcePath'] as String,
        );
      case WindowCommand.removeCustomMedia:
        await removeCustomMedia(arguments['slot'] as String);
      case WindowCommand.setBackgroundRemoval:
        await setBackgroundRemoval(
          arguments['slot'] as String,
          arguments['enabled'] as bool,
        );
      case WindowCommand.clearLocalData:
        await clearLocalData();
      case WindowCommand.quit:
        await DesktopHost.instance.quit();
    }
    _broadcastWindowState();
    return true;
  }

  Map<String, dynamic> _windowStatePayload() => <String, dynamic>{
        'snapshot': snapshot.toJson(),
        'groups': groups.map((group) => group.toJson()).toList(),
        'leaderboard': leaderboard.map((entry) => entry.toJson()).toList(),
        'chatMessages': chatMessages.map(
          (groupId, messages) => MapEntry(
            groupId,
            messages.map((message) => message.toJson()).toList(),
          ),
        ),
        'controlRoute': controlRoute.name,
        'activeChatGroupId': activeChatGroupId,
        'availableUpdate': availableUpdate?.toJson(),
        'supportsBackgroundRemoval': supportsBackgroundRemoval,
        'backendConnectionState': backendConnectionState.name,
      };

  void _broadcastWindowState() {
    unawaited(
      DesktopHost.instance.broadcastState(
        _windowStatePayload(),
        snapshot.revision,
      ),
    );
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    _broadcastWindowState();
  }

  @override
  void dispose() {
    _timer.dispose();
    _bubbles.dispose();
    _activity.dispose();
    _updateCheckTimer?.cancel();
    _interactionTimer?.cancel();
    unawaited(_webSocket.disconnect());
    super.dispose();
  }

  void _startSession(DateTime? restoredReminderAt) {
    _timer.start(
      intervalSeconds: snapshot.config.intervalSeconds,
      restoredReminderAt: restoredReminderAt,
    );
    final userId = snapshot.config.userId;
    if (userId != null) unawaited(_webSocket.connect(userId));
    unawaited(checkForUpdate(silent: true));
    _updateCheckTimer?.cancel();
    _updateCheckTimer = Timer.periodic(const Duration(hours: 6), (_) {
      unawaited(checkForUpdate(silent: true));
    });
  }

  void _onTimerChanged(TimerPhase phase, DateTime? nextReminderAt) {
    final previous = snapshot.timerPhase;
    _update(timerPhase: phase, nextReminderAt: nextReminderAt);
    unawaited(_store.saveNextReminderAt(nextReminderAt));
    if (phase == TimerPhase.running && previous != TimerPhase.running) {
      if (snapshot.config.appMode == AppMode.obedient) {
        _activity.stop();
      } else {
        _activity.start();
      }
    }
  }

  void _onTimerFire() {
    _activity.stop();
    _bubbles.add(BubbleKind.reminder);
    _update(currentSprite: '停止');
  }

  void _onBubblesChanged(List<BubbleItem> bubbles) => _update(bubbles: bubbles);

  void _onPetActivityChanged(
    PetActivityPhase phase,
    String sprite,
    bool facingLeft,
  ) =>
      _showActivitySprite(phase, sprite, facingLeft);

  void _onServerEvent(ServerEvent event) {
    switch (event) {
      case GroupCompletionEvent():
        _bubbles.add(
          BubbleKind.groupEvent,
          senderNickname: event.nickname,
          senderPetEmoji: event.petEmoji,
          senderAvatarUrl: event.avatarUrl,
          groupId: event.groupId,
        );
        _update(currentSprite: '哇');
      case ChatServerEvent():
        unawaited(_handleIncomingChat(event.message));
    }
  }

  void _onBackendConnectionStateChanged(BackendConnectionState state) {
    if (backendConnectionState == state) return;
    backendConnectionState = state;
    notifyListeners();
  }

  Future<void> _handleIncomingChat(ChatMessage message) async {
    chatMessages[message.groupId] =
        await _chatCache.merge(message.groupId, <ChatMessage>[message]);
    if (message.userId != snapshot.config.userId &&
        activeChatGroupId != message.groupId) {
      final unread = Map<String, int>.of(snapshot.unreadCounts);
      unread[message.groupId] = (unread[message.groupId] ?? 0) + 1;
      _update(unreadCounts: unread);
      _bubbles.add(
        BubbleKind.chatMessage,
        senderNickname: message.nickname,
        senderPetEmoji: message.petEmoji,
        senderAvatarUrl: message.avatarUrl,
        groupId: message.groupId,
        message: message.content,
      );
    } else {
      notifyListeners();
    }
  }

  void _markChatRead(String groupId) {
    final unread = Map<String, int>.of(snapshot.unreadCounts)..remove(groupId);
    _update(unreadCounts: unread);
  }

  Future<void> _saveGroups(List<JoinedGroup> joinedGroups) async {
    final config = snapshot.config.copyWith(joinedGroups: joinedGroups);
    _update(config: config);
    await _store.saveConfig(config);
    await refreshGroups();
  }

  Future<void> _guardBusy(Future<void> Function() action) async {
    if (isBusy) return;
    isBusy = true;
    _update(clearLastError: true);
    try {
      await action();
    } on Object catch (error) {
      _showError(_messageFor(error));
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  String _messageFor(Object error) {
    final message = error.toString();
    if (message.contains('409')) return '昵称或群组状态冲突，请换一个名称后重试';
    if (message.contains('404')) return '未找到对应群组，请检查邀请码';
    return '网络请求失败，请检查连接后重试';
  }

  void _showError(String message) {
    _update(lastError: message);
    Future<void>.delayed(const Duration(seconds: 4), () {
      if (snapshot.lastError == message) _update(clearLastError: true);
    });
  }

  void _update({
    UserConfig? config,
    TimerPhase? timerPhase,
    PetActivityPhase? petActivityPhase,
    List<BubbleItem>? bubbles,
    Map<String, int>? unreadCounts,
    DateTime? nextReminderAt,
    String? currentSprite,
    bool clearCurrentSprite = false,
    bool? petFacingLeft,
    PetDockSide? dockSide,
    bool clearDockSide = false,
    String? lastError,
    bool clearLastError = false,
  }) {
    snapshot = snapshot.copyWith(
      revision: snapshot.revision + 1,
      config: config,
      timerPhase: timerPhase,
      petActivityPhase: petActivityPhase,
      bubbles: bubbles,
      unreadCounts: unreadCounts,
      nextReminderAt: nextReminderAt,
      currentSprite: currentSprite,
      clearCurrentSprite: clearCurrentSprite,
      petFacingLeft: petFacingLeft,
      dockSide: dockSide,
      clearDockSide: clearDockSide,
      lastError: lastError,
      clearLastError: clearLastError,
    );
    notifyListeners();
  }
}

class ReplicaAppController extends AppController {
  ReplicaAppController({
    required this.launch,
    required super.store,
    required super.apiClient,
  });

  final WindowLaunchArguments launch;

  @override
  Future<void> initialize() async {
    if (isReady) return;
    controlRoute = launch.route ?? ControlRoute.timer;
    activeChatGroupId = launch.groupId;
    isReady = true;
    super.notifyListeners();
    await DesktopHost.instance.bindReplica(
      _applyWindowState,
      onNavigate: (route, groupId) {
        controlRoute = route;
        if (groupId != null) {
          activeChatGroupId = groupId;
          unawaited(loadChat(groupId));
        }
        super.notifyListeners();
      },
    );
  }

  void _applyWindowState(Map<String, dynamic> payload, int revision) {
    if (revision < snapshot.revision) return;
    snapshot =
        AppSnapshot.fromJson(payload['snapshot'] as Map<String, dynamic>);
    groups = (payload['groups'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(GroupInfo.fromJson)
        .toList(growable: false);
    leaderboard =
        (payload['leaderboard'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(LeaderboardEntry.fromJson)
            .toList(growable: false);
    chatMessages
      ..clear()
      ..addAll(
        (payload['chatMessages'] as Map<String, dynamic>? ??
                const <String, dynamic>{})
            .map(
          (groupId, rawMessages) => MapEntry(
            groupId,
            (rawMessages as List<dynamic>)
                .whereType<Map<String, dynamic>>()
                .map(ChatMessage.fromJson)
                .toList(growable: false),
          ),
        ),
      );
    availableUpdate = payload['availableUpdate'] == null
        ? null
        : AppVersionInfo.fromJson(
            payload['availableUpdate'] as Map<String, dynamic>,
          );
    supportsBackgroundRemoval =
        payload['supportsBackgroundRemoval'] as bool? ?? false;
    backendConnectionState = BackendConnectionState.values.byName(
      payload['backendConnectionState'] as String? ??
          BackendConnectionState.disconnected.name,
    );
    activeChatGroupId = payload['activeChatGroupId'] as String?;
    super.notifyListeners();
  }

  @override
  Future<void> modifyInterval(int seconds) => DesktopHost.instance.sendCommand(
        WindowCommand.modifyInterval,
        arguments: <String, dynamic>{'seconds': seconds},
      );

  @override
  Future<void> completeReminder() =>
      DesktopHost.instance.sendCommand(WindowCommand.completeReminder);

  @override
  void skipReminder() =>
      unawaited(DesktopHost.instance.sendCommand(WindowCommand.skipReminder));

  @override
  Future<void> toggleObedientMode() =>
      DesktopHost.instance.sendCommand(WindowCommand.toggleObedientMode);

  @override
  void selectControlRoute(ControlRoute route, {String? groupId}) {
    super.selectControlRoute(route, groupId: groupId);
    unawaited(DesktopHost.instance.updateControlWindowRoute(route));
    unawaited(
      DesktopHost.instance.sendCommand(
        WindowCommand.openControlCenter,
        arguments: <String, dynamic>{
          'route': route.name,
          'groupId': groupId,
        },
      ),
    );
  }

  @override
  Future<void> openControlCenter(
    ControlRoute route, {
    String? groupId,
  }) =>
      DesktopHost.instance.sendCommand(
        WindowCommand.openControlCenter,
        arguments: <String, dynamic>{
          'route': route.name,
          'groupId': groupId,
        },
      );

  @override
  Future<void> refreshGroups() =>
      DesktopHost.instance.sendCommand(WindowCommand.refreshGroups);

  @override
  Future<void> refreshLeaderboard(String groupId) =>
      DesktopHost.instance.sendCommand(
        WindowCommand.refreshLeaderboard,
        arguments: <String, dynamic>{'groupId': groupId},
      );

  @override
  Future<void> loadChat(String groupId) => DesktopHost.instance.sendCommand(
        WindowCommand.loadChat,
        arguments: <String, dynamic>{'groupId': groupId},
      );

  @override
  Future<void> sendChat(String groupId, String content) =>
      DesktopHost.instance.sendCommand(
        WindowCommand.sendChat,
        arguments: <String, dynamic>{
          'groupId': groupId,
          'content': content,
        },
      );

  @override
  Future<void> createGroup(String name) => DesktopHost.instance.sendCommand(
        WindowCommand.createGroup,
        arguments: <String, dynamic>{'name': name},
      );

  @override
  Future<void> joinGroup(String code) => DesktopHost.instance.sendCommand(
        WindowCommand.joinGroup,
        arguments: <String, dynamic>{'code': code},
      );

  @override
  Future<void> leaveGroup(String groupId) => DesktopHost.instance.sendCommand(
        WindowCommand.leaveGroup,
        arguments: <String, dynamic>{'groupId': groupId},
      );

  @override
  Future<void> checkForUpdate({bool silent = false}) =>
      DesktopHost.instance.sendCommand(WindowCommand.checkForUpdate);

  @override
  Future<void> saveCustomMedia(String slot, String sourcePath) =>
      DesktopHost.instance.sendCommand(
        WindowCommand.saveCustomMedia,
        arguments: <String, dynamic>{
          'slot': slot,
          'sourcePath': sourcePath,
        },
      );

  @override
  Future<void> removeCustomMedia(String slot) =>
      DesktopHost.instance.sendCommand(
        WindowCommand.removeCustomMedia,
        arguments: <String, dynamic>{'slot': slot},
      );

  @override
  Future<void> setBackgroundRemoval(String slot, bool enabled) =>
      DesktopHost.instance.sendCommand(
        WindowCommand.setBackgroundRemoval,
        arguments: <String, dynamic>{'slot': slot, 'enabled': enabled},
      );

  @override
  Future<void> clearLocalData() =>
      DesktopHost.instance.sendCommand(WindowCommand.clearLocalData);
}
