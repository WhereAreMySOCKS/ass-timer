import 'package:ass_timer_flutter/data/web_socket_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes a valid group event', () {
    final event = decodeServerEvent(
      '{"type":"group_event","group_id":"g1",'
      '"data":{"nickname":"小鹿","pet_emoji":"🦌"}}',
    );

    expect(event, isA<GroupCompletionEvent>());
    expect((event! as GroupCompletionEvent).nickname, '小鹿');
  });

  test('rejects malformed and incomplete messages', () {
    expect(() => decodeServerEvent('{bad json'), throwsFormatException);
    expect(
      () => decodeServerEvent('{"type":"group_event","data":{}}'),
      throwsFormatException,
    );
  });

  test('ignores valid message types that are not handled', () {
    expect(decodeServerEvent('{"type":"pong"}'), isNull);
  });
}
