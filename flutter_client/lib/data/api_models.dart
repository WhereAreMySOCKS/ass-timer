class ChatMessage {
  const ChatMessage({
    required this.sequence,
    required this.messageId,
    required this.groupId,
    required this.userId,
    required this.nickname,
    required this.petEmoji,
    required this.avatarUrl,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        sequence: (json['sequence'] as num?)?.toInt() ?? 0,
        messageId: json['message_id'] as String,
        groupId: json['group_id'] as String,
        userId: json['user_id'] as String,
        nickname: json['nickname'] as String,
        petEmoji: json['pet_emoji'] as String? ?? '🦌',
        avatarUrl: json['avatar_url'] as String? ?? '',
        content: json['content'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );

  final int sequence;
  final String messageId;
  final String groupId;
  final String userId;
  final String nickname;
  final String petEmoji;
  final String avatarUrl;
  final String content;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sequence': sequence,
        'message_id': messageId,
        'group_id': groupId,
        'user_id': userId,
        'nickname': nickname,
        'pet_emoji': petEmoji,
        'avatar_url': avatarUrl,
        'content': content,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  static int chronologicalOrder(ChatMessage a, ChatMessage b) {
    final sequenceOrder = a.sequence.compareTo(b.sequence);
    return sequenceOrder != 0
        ? sequenceOrder
        : a.createdAt.compareTo(b.createdAt);
  }
}

class GroupMember {
  const GroupMember({
    required this.userId,
    required this.nickname,
    required this.petEmoji,
    required this.avatarUrl,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) => GroupMember(
        userId: json['user_id'] as String,
        nickname: json['nickname'] as String,
        petEmoji: json['pet_emoji'] as String? ?? '🦌',
        avatarUrl: json['avatar_url'] as String? ?? '',
      );

  final String userId;
  final String nickname;
  final String petEmoji;
  final String avatarUrl;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'user_id': userId,
        'nickname': nickname,
        'pet_emoji': petEmoji,
        'avatar_url': avatarUrl,
      };
}

class GroupInfo {
  const GroupInfo({
    required this.groupId,
    required this.name,
    required this.inviteCode,
    required this.members,
  });

  factory GroupInfo.fromJson(Map<String, dynamic> json) => GroupInfo(
        groupId: json['group_id'] as String,
        name: json['name'] as String,
        inviteCode: json['invite_code'] as String,
        members: (json['members'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(GroupMember.fromJson)
            .toList(growable: false),
      );

  final String groupId;
  final String name;
  final String inviteCode;
  final List<GroupMember> members;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'group_id': groupId,
        'name': name,
        'invite_code': inviteCode,
        'members': members.map((member) => member.toJson()).toList(),
      };
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.nickname,
    required this.petEmoji,
    required this.avatarUrl,
    required this.count,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        rank: (json['rank'] as num).toInt(),
        userId: json['user_id'] as String,
        nickname: json['nickname'] as String,
        petEmoji: json['pet_emoji'] as String? ?? '🦌',
        avatarUrl: json['avatar_url'] as String? ?? '',
        count: (json['count'] as num).toInt(),
      );

  final int rank;
  final String userId;
  final String nickname;
  final String petEmoji;
  final String avatarUrl;
  final int count;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'rank': rank,
        'user_id': userId,
        'nickname': nickname,
        'pet_emoji': petEmoji,
        'avatar_url': avatarUrl,
        'count': count,
      };
}

class AppVersionInfo {
  const AppVersionInfo({
    required this.latestVersion,
    required this.minRequiredVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.forceUpdate,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) => AppVersionInfo(
        latestVersion: json['latest_version'] as String,
        minRequiredVersion: json['min_required_version'] as String,
        downloadUrl: json['download_url'] as String,
        releaseNotes: json['release_notes'] as String? ?? '',
        forceUpdate: json['force_update'] as bool? ?? false,
      );

  final String latestVersion;
  final String minRequiredVersion;
  final String downloadUrl;
  final String releaseNotes;
  final bool forceUpdate;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'latest_version': latestVersion,
        'min_required_version': minRequiredVersion,
        'download_url': downloadUrl,
        'release_notes': releaseNotes,
        'force_update': forceUpdate,
      };
}
