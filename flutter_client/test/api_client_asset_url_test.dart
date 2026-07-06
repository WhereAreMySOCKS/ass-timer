import 'package:ass_timer_flutter/data/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps absolute avatar URLs unchanged', () {
    expect(
      resolveApiAssetUrl('https://cdn.example.com/avatar.png'),
      'https://cdn.example.com/avatar.png',
    );
  });

  test('resolves backend avatar paths under the configured API prefix', () {
    expect(
      resolveApiAssetUrl(
        '/uploads/avatars/user.png',
        baseUrl: 'https://api.example.com/ass-timer/',
      ),
      'https://api.example.com/ass-timer/uploads/avatars/user.png',
    );
  });
}
