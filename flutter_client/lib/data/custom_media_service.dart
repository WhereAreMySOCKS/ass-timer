import 'dart:io';
import 'dart:isolate';

import 'package:ass_timer_flutter/data/app_store.dart';
import 'package:ass_timer_flutter/domain/app_models.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class CustomMediaService {
  CustomMediaService(this._store);

  static const int maximumFileBytes = 10 * 1024 * 1024;
  final AppStore _store;
  static const MethodChannel _nativeChannel =
      MethodChannel('ass_timer/legacy_migration');

  Future<bool> supportsBackgroundRemoval() async {
    if (!Platform.isMacOS) return false;
    try {
      return await _nativeChannel
              .invokeMethod<bool>('supportsBackgroundRemoval') ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<CustomActionMediaEntry> importImage(
    String slot,
    String sourcePath, {
    CustomActionMediaEntry? replacing,
  }) async {
    final source = File(sourcePath);
    final length = await source.length();
    if (length <= 0 || length > maximumFileBytes) {
      throw const FormatException('请选择 10MB 以内的图片');
    }
    final bytes = await source.readAsBytes();
    final backgroundPng = await Isolate.run(() => _makeBackground(bytes));
    final root = await _store.customMediaRoot();
    final revision = const Uuid().v4();
    final extension = _safeExtension(sourcePath);
    final stem = '$slot-${revision.toLowerCase()}';
    final sourceName = '$stem-source.$extension';
    final backgroundName = '$stem-background.png';
    await File(p.join(root.path, sourceName)).writeAsBytes(bytes, flush: true);
    await File(p.join(root.path, backgroundName))
        .writeAsBytes(backgroundPng, flush: true);
    if (replacing != null) await remove(replacing);
    return CustomActionMediaEntry(
      sourceFileName: sourceName,
      backgroundFileName: backgroundName,
      removesBackground: false,
      revision: revision,
    );
  }

  Future<void> remove(CustomActionMediaEntry entry) async {
    final root = await _store.customMediaRoot();
    for (final name in <String?>[
      entry.sourceFileName,
      entry.backgroundFileName,
      entry.foregroundFileName,
    ]) {
      if (name != null) {
        final file = File(p.join(root.path, name));
        if (file.existsSync()) await file.delete();
      }
    }
  }

  Future<CustomActionMediaEntry> setBackgroundRemoval(
    CustomActionMediaEntry entry,
    bool enabled,
  ) async {
    if (!enabled) {
      return CustomActionMediaEntry(
        sourceFileName: entry.sourceFileName,
        backgroundFileName: entry.backgroundFileName,
        foregroundFileName: entry.foregroundFileName,
        removesBackground: false,
        revision: entry.revision,
      );
    }
    if (!Platform.isMacOS) {
      throw const FormatException('当前系统不支持本地去背景');
    }
    final root = await _store.customMediaRoot();
    final source =
        await File(p.join(root.path, entry.sourceFileName)).readAsBytes();
    final result = await _nativeChannel.invokeMethod<Uint8List>(
      'removeBackground',
      <String, dynamic>{'data': source, 'width': 216, 'height': 288},
    );
    if (result == null) throw const FormatException('图片处理失败');
    final foregroundName =
        '${p.basenameWithoutExtension(entry.backgroundFileName)}-foreground.png';
    await File(p.join(root.path, foregroundName))
        .writeAsBytes(result, flush: true);
    return CustomActionMediaEntry(
      sourceFileName: entry.sourceFileName,
      backgroundFileName: entry.backgroundFileName,
      foregroundFileName: foregroundName,
      removesBackground: true,
      revision: entry.revision,
    );
  }

  static Uint8List _makeBackground(Uint8List source) {
    var image = img.decodeImage(source);
    if (image == null) throw const FormatException('无法读取图片');
    image = img.bakeOrientation(image);
    const outputWidth = 216;
    const outputHeight = 288;
    final scale = (outputWidth / image.width)
        .clamp(outputHeight / image.height, double.infinity);
    final resized = img.copyResize(
      image,
      width: (image.width * scale).round(),
      height: (image.height * scale).round(),
      interpolation: img.Interpolation.cubic,
    );
    final x =
        ((resized.width - outputWidth) / 2).round().clamp(0, resized.width);
    final y =
        ((resized.height - outputHeight) / 2).round().clamp(0, resized.height);
    final cropped = img.copyCrop(
      resized,
      x: x,
      y: y,
      width: outputWidth,
      height: outputHeight,
    );
    return Uint8List.fromList(img.encodePng(cropped, level: 6));
  }

  static String _safeExtension(String sourcePath) {
    final extension =
        p.extension(sourcePath).replaceFirst('.', '').toLowerCase();
    return const <String>{'png', 'jpg', 'jpeg', 'webp'}.contains(extension)
        ? extension
        : 'img';
  }
}
