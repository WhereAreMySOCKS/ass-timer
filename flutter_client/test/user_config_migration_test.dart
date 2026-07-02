import 'dart:convert';

import 'package:ass_timer_flutter/domain/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes the Swift UserConfig JSON shape', () {
    final config = UserConfig.fromJson(
      jsonDecode('''
      {
        "userID":"user-1",
        "nickname":"小鹿",
        "petEmoji":"🦌",
        "petImageName":"pet_deer",
        "avatarURL":"/uploads/avatars/deer.png",
        "intervalSeconds":2400,
        "appMode":"obedient",
        "joinedGroups":[
          {"groupID":"group-1","groupName":"办公室","inviteCode":"ABC123"}
        ],
        "localEventCount":42,
        "onboardingComplete":true,
        "windowOriginX":120.5,
        "windowOriginY":88.0,
        "customActionMedia":{
          "reminder":null,
          "nap":{
            "sourceFileName":"nap-source.jpg",
            "backgroundFileName":"nap-background.png",
            "foregroundFileName":null,
            "removesBackground":false,
            "revision":"6B5B89CE-3A22-4587-9704-A5B3A0A9D831"
          }
        }
      }
      ''') as Map<String, dynamic>,
    );

    expect(config.userId, 'user-1');
    expect(config.appMode, AppMode.obedient);
    expect(config.joinedGroups.single.inviteCode, 'ABC123');
    expect(config.localEventCount, 42);
    expect(config.customActionMedia.keys, <String>['nap']);
    expect(config.hasCompletedOnboarding, isTrue);
  });

  test('does not skip onboarding for an incomplete test configuration', () {
    const config = UserConfig(onboardingComplete: true);

    expect(config.hasCompletedOnboarding, isFalse);
  });
}
