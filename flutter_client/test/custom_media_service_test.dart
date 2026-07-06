import 'dart:typed_data';

import 'package:ass_timer_flutter/data/custom_media_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts a single-frame image up to 16 million pixels', () {
    expect(
      () => validateCustomImageMetadata(
        width: 4000,
        height: 4000,
        frameCount: 1,
      ),
      returnsNormally,
    );
  });

  test('rejects excessive pixel count and multiple frames', () {
    expect(
      () => validateCustomImageMetadata(
        width: 4001,
        height: 4000,
        frameCount: 1,
      ),
      throwsFormatException,
    );
    expect(
      () => validateCustomImageMetadata(
        width: 100,
        height: 100,
        frameCount: 2,
      ),
      throwsFormatException,
    );
  });

  test('rejects corrupt encoded image data', () {
    expect(
      () => decodeValidatedCustomImage(Uint8List.fromList(<int>[0, 1, 2, 3])),
      throwsFormatException,
    );
  });
}
