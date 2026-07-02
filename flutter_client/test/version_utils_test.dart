import 'package:ass_timer_flutter/domain/version_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compares normalized semantic versions', () {
    expect(VersionUtils.compare('v2.0.0', '1.9.9'), greaterThan(0));
    expect(VersionUtils.compare('2.0', '2.0.0'), 0);
    expect(VersionUtils.compare('2.0.0', '2.0.1'), lessThan(0));
  });
}
