import 'dart:io';

import 'package:ass_timer_flutter/data/app_store.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

class AvatarCache {
  AvatarCache(AppStore store, {Dio? dio})
      : _rootProvider = store.appSupportRoot,
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 8),
              ),
            );

  AvatarCache.forRoot(this._rootProvider, {Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 8),
              ),
            );

  final Future<Directory> Function() _rootProvider;
  final Dio _dio;
  final Map<String, Future<String?>> _inFlight = <String, Future<String?>>{};

  Future<String?> pathFor(String url) {
    final normalized = url.trim();
    if (normalized.isEmpty) return Future<String?>.value();
    return _inFlight.putIfAbsent(normalized, () async {
      try {
        return await _loadOrDownload(normalized);
      } finally {
        _inFlight.remove(normalized);
      }
    });
  }

  Future<String?> _loadOrDownload(String url) async {
    final root = await _rootProvider();
    final directory = Directory(p.join(root.path, 'avatar-cache'));
    if (!directory.existsSync()) await directory.create(recursive: true);
    final file =
        File(p.join(directory.path, sha256.convert(url.codeUnits).toString()));
    if (file.existsSync() && file.lengthSync() > 0) return file.path;

    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return null;
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } on Object {
      return file.existsSync() && file.lengthSync() > 0 ? file.path : null;
    }
  }
}
