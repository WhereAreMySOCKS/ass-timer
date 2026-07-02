import 'dart:io';

import 'package:ass_timer_flutter/data/api_models.dart';
import 'package:ass_timer_flutter/domain/app_models.dart';
import 'package:dio/dio.dart';

const String defaultApiBaseUrl = String.fromEnvironment(
  'ASS_TIMER_API_URL',
  defaultValue: 'https://api.guiji.online/ass-timer',
);

class ApiClient {
  ApiClient({Dio? dio, String baseUrl = defaultApiBaseUrl})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 15),
              ),
            );

  final Dio _dio;

  Future<UserConfig> createUser({
    required String nickname,
    required String avatarPath,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/user/create',
      data: FormData.fromMap(<String, dynamic>{
        'nickname': nickname,
        'avatar': await MultipartFile.fromFile(avatarPath),
      }),
    );
    final json = _requireMap(response);
    return UserConfig(
      userId: json['user_id'] as String,
      nickname: json['nickname'] as String,
      petEmoji: json['pet_emoji'] as String? ?? '🦌',
      petImageName: 'pet_deer',
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Future<void> deleteUser(String userId) async {
    await _dio.delete<void>('/user/$userId');
  }

  Future<JoinedGroup> createGroup(String userId, String name) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/group/create',
      data: <String, dynamic>{
        'creator_user_id': userId,
        'group_name': name,
      },
    );
    return _joinedGroup(_requireMap(response));
  }

  Future<JoinedGroup> joinGroup(String userId, String inviteCode) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/group/join',
      data: <String, dynamic>{
        'user_id': userId,
        'invite_code': inviteCode.toUpperCase(),
      },
    );
    return _joinedGroup(_requireMap(response));
  }

  Future<void> leaveGroup(String userId, String groupId) async {
    await _dio.post<Map<String, dynamic>>(
      '/group/leave',
      data: <String, dynamic>{'user_id': userId, 'group_id': groupId},
    );
  }

  Future<List<GroupInfo>> getUserGroups(String userId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/user/$userId/groups',
    );
    final groups =
        _requireMap(response)['groups'] as List<dynamic>? ?? const <dynamic>[];
    return groups
        .whereType<Map<String, dynamic>>()
        .map(GroupInfo.fromJson)
        .toList(growable: false);
  }

  Future<GroupInfo> getGroupInfo(String groupId) async {
    final response =
        await _dio.get<Map<String, dynamic>>('/group/$groupId/info');
    return GroupInfo.fromJson(_requireMap(response));
  }

  Future<List<LeaderboardEntry>> getLeaderboard(String groupId) async {
    final response =
        await _dio.get<Map<String, dynamic>>('/group/$groupId/rank');
    final entries =
        _requireMap(response)['entries'] as List<dynamic>? ?? const <dynamic>[];
    return entries
        .whereType<Map<String, dynamic>>()
        .map(LeaderboardEntry.fromJson)
        .toList(growable: false);
  }

  Future<({List<ChatMessage> messages, bool hasMore})> getChatHistory(
    String groupId, {
    int limit = 50,
    String? beforeId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/group/$groupId/messages',
      queryParameters: <String, dynamic>{
        'limit': limit,
        if (beforeId != null) 'before_id': beforeId,
      },
    );
    final json = _requireMap(response);
    return (
      messages: (json['messages'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList(growable: false),
      hasMore: json['has_more'] as bool? ?? false,
    );
  }

  Future<ChatMessage> sendChatMessage(
    String groupId,
    String userId,
    String content,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/group/$groupId/messages',
      data: <String, dynamic>{'user_id': userId, 'content': content},
    );
    return ChatMessage.fromJson(_requireMap(response));
  }

  Future<void> logEvent(String userId, List<String> groupIds) async {
    await _dio.post<Map<String, dynamic>>(
      '/event',
      data: <String, dynamic>{
        'user_id': userId,
        if (groupIds.isNotEmpty) 'group_ids': groupIds,
      },
    );
  }

  Future<AppVersionInfo> getVersion() async {
    final platform = Platform.isWindows ? 'windows' : 'macos';
    final response = await _dio.get<Map<String, dynamic>>(
      '/app/version',
      queryParameters: <String, dynamic>{'platform': platform},
      options: Options(headers: <String, String>{'Cache-Control': 'no-cache'}),
    );
    return AppVersionInfo.fromJson(_requireMap(response));
  }

  static JoinedGroup _joinedGroup(Map<String, dynamic> json) => JoinedGroup(
        groupId: json['group_id'] as String,
        groupName: json['name'] as String,
        inviteCode: json['invite_code'] as String,
      );

  static Map<String, dynamic> _requireMap(
    Response<Map<String, dynamic>> response,
  ) {
    final data = response.data;
    if (data == null) throw const FormatException('Empty API response');
    return data;
  }
}
