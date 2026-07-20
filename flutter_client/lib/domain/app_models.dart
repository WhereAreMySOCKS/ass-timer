import 'dart:convert';

enum AppMode { normal, obedient }

enum TimerPhase { idle, running, reminder, confirming, reset }

enum PetActivityPhase { standing, walking, flying, napping }

enum PetDockSide { left, right }

enum BubbleKind { reminder, feedback, groupEvent, chatMessage }

enum BubbleFeedbackTone { success, warning }

enum BackendConnectionState { disconnected, connecting, connected }

enum ControlRoute { timer, groups, chat, leaderboard, media, about }

enum WindowRole { pet, bubble, controlCenter }

class JoinedGroup {
  const JoinedGroup({
    required this.groupId,
    required this.groupName,
    required this.inviteCode,
  });

  factory JoinedGroup.fromJson(Map<String, dynamic> json) => JoinedGroup(
        groupId: (json['groupID'] ?? json['group_id'] ?? '') as String,
        groupName: (json['groupName'] ?? json['group_name'] ?? '') as String,
        inviteCode: (json['inviteCode'] ?? json['invite_code'] ?? '') as String,
      );

  final String groupId;
  final String groupName;
  final String inviteCode;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'groupID': groupId,
        'groupName': groupName,
        'inviteCode': inviteCode,
      };
}

class CustomActionMediaEntry {
  const CustomActionMediaEntry({
    required this.sourceFileName,
    required this.backgroundFileName,
    required this.removesBackground,
    required this.revision,
    this.foregroundFileName,
  });

  factory CustomActionMediaEntry.fromJson(Map<String, dynamic> json) =>
      CustomActionMediaEntry(
        sourceFileName: json['sourceFileName'] as String,
        backgroundFileName: json['backgroundFileName'] as String,
        foregroundFileName: json['foregroundFileName'] as String?,
        removesBackground: json['removesBackground'] as bool? ?? false,
        revision: json['revision'] as String? ?? '',
      );

  final String sourceFileName;
  final String backgroundFileName;
  final String? foregroundFileName;
  final bool removesBackground;
  final String revision;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sourceFileName': sourceFileName,
        'backgroundFileName': backgroundFileName,
        'foregroundFileName': foregroundFileName,
        'removesBackground': removesBackground,
        'revision': revision,
      };
}

class UserConfig {
  const UserConfig({
    this.userId,
    this.nickname,
    this.petEmoji = '🦌',
    this.petImageName = 'pet_deer',
    this.avatarUrl,
    this.intervalSeconds = 2400,
    this.appMode = AppMode.normal,
    this.joinedGroups = const <JoinedGroup>[],
    this.localEventCount = 0,
    this.onboardingComplete = false,
    this.windowOriginX,
    this.windowOriginY,
    this.customActionMedia = const <String, CustomActionMediaEntry>{},
  });

  factory UserConfig.fromJson(Map<String, dynamic> json) {
    final mediaJson = json['customActionMedia'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    return UserConfig(
      userId: json['userID'] as String?,
      nickname: json['nickname'] as String?,
      petEmoji: json['petEmoji'] as String? ?? '🦌',
      petImageName: json['petImageName'] as String? ?? 'pet_deer',
      avatarUrl: json['avatarURL'] as String?,
      intervalSeconds: (json['intervalSeconds'] as num?)?.toInt() ?? 2400,
      appMode:
          json['appMode'] == 'obedient' ? AppMode.obedient : AppMode.normal,
      joinedGroups:
          (json['joinedGroups'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(JoinedGroup.fromJson)
              .toList(growable: false),
      localEventCount: (json['localEventCount'] as num?)?.toInt() ?? 0,
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      windowOriginX: (json['windowOriginX'] as num?)?.toDouble(),
      windowOriginY: (json['windowOriginY'] as num?)?.toDouble(),
      customActionMedia: <String, CustomActionMediaEntry>{
        for (final entry in mediaJson.entries)
          if (entry.value is Map<String, dynamic>)
            entry.key: CustomActionMediaEntry.fromJson(
              entry.value as Map<String, dynamic>,
            ),
      },
    );
  }

  final String? userId;
  final String? nickname;
  final String petEmoji;
  final String petImageName;
  final String? avatarUrl;
  final int intervalSeconds;
  final AppMode appMode;
  final List<JoinedGroup> joinedGroups;
  final int localEventCount;
  final bool onboardingComplete;
  final double? windowOriginX;
  final double? windowOriginY;
  final Map<String, CustomActionMediaEntry> customActionMedia;

  bool get hasGroup => joinedGroups.isNotEmpty;
  bool get hasCompletedOnboarding =>
      onboardingComplete &&
      (userId?.trim().isNotEmpty ?? false) &&
      (nickname?.trim().isNotEmpty ?? false);

  UserConfig copyWith({
    String? userId,
    String? nickname,
    String? petEmoji,
    String? petImageName,
    String? avatarUrl,
    int? intervalSeconds,
    AppMode? appMode,
    List<JoinedGroup>? joinedGroups,
    int? localEventCount,
    bool? onboardingComplete,
    double? windowOriginX,
    double? windowOriginY,
    Map<String, CustomActionMediaEntry>? customActionMedia,
  }) =>
      UserConfig(
        userId: userId ?? this.userId,
        nickname: nickname ?? this.nickname,
        petEmoji: petEmoji ?? this.petEmoji,
        petImageName: petImageName ?? this.petImageName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        intervalSeconds: intervalSeconds ?? this.intervalSeconds,
        appMode: appMode ?? this.appMode,
        joinedGroups: joinedGroups ?? this.joinedGroups,
        localEventCount: localEventCount ?? this.localEventCount,
        onboardingComplete: onboardingComplete ?? this.onboardingComplete,
        windowOriginX: windowOriginX ?? this.windowOriginX,
        windowOriginY: windowOriginY ?? this.windowOriginY,
        customActionMedia: customActionMedia ?? this.customActionMedia,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'userID': userId,
        'nickname': nickname,
        'petEmoji': petEmoji,
        'petImageName': petImageName,
        'avatarURL': avatarUrl,
        'intervalSeconds': intervalSeconds,
        'appMode': appMode.name,
        'joinedGroups': joinedGroups.map((group) => group.toJson()).toList(),
        'localEventCount': localEventCount,
        'onboardingComplete': onboardingComplete,
        'windowOriginX': windowOriginX,
        'windowOriginY': windowOriginY,
        'customActionMedia': customActionMedia.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
      };

  String encode() => jsonEncode(toJson());
}

class BubbleItem {
  BubbleItem({
    required this.id,
    required this.kind,
    required this.createdAt,
    this.senderNickname,
    this.senderPetEmoji,
    this.senderAvatarUrl,
    this.groupId,
    this.message,
    this.feedbackTone,
  });

  factory BubbleItem.fromJson(Map<String, dynamic> json) => BubbleItem(
        id: json['id'] as String,
        kind: BubbleKind.values.byName(json['kind'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        senderNickname: json['senderNickname'] as String?,
        senderPetEmoji: json['senderPetEmoji'] as String?,
        senderAvatarUrl: json['senderAvatarUrl'] as String?,
        groupId: json['groupId'] as String?,
        message: json['message'] as String?,
        feedbackTone: json['feedbackTone'] == null
            ? null
            : BubbleFeedbackTone.values.byName(
                json['feedbackTone'] as String,
              ),
      );

  final String id;
  final BubbleKind kind;
  final DateTime createdAt;
  final String? senderNickname;
  final String? senderPetEmoji;
  final String? senderAvatarUrl;
  final String? groupId;
  final String? message;
  final BubbleFeedbackTone? feedbackTone;

  int get priority => switch (kind) {
        BubbleKind.reminder => 0,
        BubbleKind.feedback => 1,
        BubbleKind.groupEvent || BubbleKind.chatMessage => 2,
      };

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'kind': kind.name,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'senderNickname': senderNickname,
        'senderPetEmoji': senderPetEmoji,
        'senderAvatarUrl': senderAvatarUrl,
        'groupId': groupId,
        'message': message,
        'feedbackTone': feedbackTone?.name,
      };
}

class AppSnapshot {
  const AppSnapshot({
    required this.revision,
    required this.config,
    required this.timerPhase,
    required this.petActivityPhase,
    required this.bubbles,
    required this.unreadCounts,
    this.nextReminderAt,
    this.currentSprite,
    this.petFacingLeft = false,
    this.dockSide,
    this.lastError,
  });

  factory AppSnapshot.initial() => const AppSnapshot(
        revision: 0,
        config: UserConfig(),
        timerPhase: TimerPhase.idle,
        petActivityPhase: PetActivityPhase.standing,
        bubbles: <BubbleItem>[],
        unreadCounts: <String, int>{},
      );

  factory AppSnapshot.fromJson(Map<String, dynamic> json) => AppSnapshot(
        revision: (json['revision'] as num?)?.toInt() ?? 0,
        config: UserConfig.fromJson(json['config'] as Map<String, dynamic>),
        timerPhase: TimerPhase.values.byName(json['timerPhase'] as String),
        petActivityPhase:
            PetActivityPhase.values.byName(json['petActivityPhase'] as String),
        bubbles: (json['bubbles'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(BubbleItem.fromJson)
            .toList(growable: false),
        unreadCounts: (json['unreadCounts'] as Map<String, dynamic>? ??
                const <String, dynamic>{})
            .map((key, value) => MapEntry(key, (value as num).toInt())),
        nextReminderAt: json['nextReminderAt'] == null
            ? null
            : DateTime.parse(json['nextReminderAt'] as String).toLocal(),
        currentSprite: json['currentSprite'] as String?,
        petFacingLeft: json['petFacingLeft'] as bool? ?? false,
        dockSide: json['dockSide'] == null
            ? null
            : PetDockSide.values.byName(json['dockSide'] as String),
        lastError: json['lastError'] as String?,
      );

  final int revision;
  final UserConfig config;
  final TimerPhase timerPhase;
  final PetActivityPhase petActivityPhase;
  final List<BubbleItem> bubbles;
  final Map<String, int> unreadCounts;
  final DateTime? nextReminderAt;
  final String? currentSprite;
  final bool petFacingLeft;
  final PetDockSide? dockSide;
  final String? lastError;

  AppSnapshot copyWith({
    int? revision,
    UserConfig? config,
    TimerPhase? timerPhase,
    PetActivityPhase? petActivityPhase,
    List<BubbleItem>? bubbles,
    Map<String, int>? unreadCounts,
    DateTime? nextReminderAt,
    bool clearNextReminderAt = false,
    String? currentSprite,
    bool clearCurrentSprite = false,
    bool? petFacingLeft,
    PetDockSide? dockSide,
    bool clearDockSide = false,
    String? lastError,
    bool clearLastError = false,
  }) =>
      AppSnapshot(
        revision: revision ?? this.revision,
        config: config ?? this.config,
        timerPhase: timerPhase ?? this.timerPhase,
        petActivityPhase: petActivityPhase ?? this.petActivityPhase,
        bubbles: bubbles ?? this.bubbles,
        unreadCounts: unreadCounts ?? this.unreadCounts,
        nextReminderAt:
            clearNextReminderAt ? null : nextReminderAt ?? this.nextReminderAt,
        currentSprite:
            clearCurrentSprite ? null : currentSprite ?? this.currentSprite,
        petFacingLeft: petFacingLeft ?? this.petFacingLeft,
        dockSide: clearDockSide ? null : dockSide ?? this.dockSide,
        lastError: clearLastError ? null : lastError ?? this.lastError,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'revision': revision,
        'config': config.toJson(),
        'timerPhase': timerPhase.name,
        'petActivityPhase': petActivityPhase.name,
        'bubbles': bubbles.map((bubble) => bubble.toJson()).toList(),
        'unreadCounts': unreadCounts,
        'nextReminderAt': nextReminderAt?.toUtc().toIso8601String(),
        'currentSprite': currentSprite,
        'petFacingLeft': petFacingLeft,
        'dockSide': dockSide?.name,
        'lastError': lastError,
      };
}
