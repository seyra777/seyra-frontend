import 'dart:io';

import 'package:path_provider/path_provider.dart';

final class StorageUsageBreakdown {
  const StorageUsageBreakdown({
    required this.cacheBytes,
    required this.supportBytes,
    required this.tempBytes,
  });

  final int cacheBytes;
  final int supportBytes;
  final int tempBytes;

  int get totalBytes => cacheBytes + supportBytes + tempBytes;
}

/// App-local size estimates. Not the OS “App storage” total (databases
/// inside the OS sandbox may sit outside these directories).
abstract final class LocalAppData {
  static Future<StorageUsageBreakdown> measure() async {
    final cache = await _safeSize(() async => getApplicationCacheDirectory());
    final support = await _safeSize(
      () async => getApplicationSupportDirectory(),
    );
    final temp = await _safeSize(() async => getTemporaryDirectory());
    return StorageUsageBreakdown(
      cacheBytes: cache,
      supportBytes: support,
      tempBytes: temp,
    );
  }

  /// Deletes cache and temporary files only. Does not touch secure storage
  /// (auth tokens, Signal identity) or application-support databases.
  static Future<void> clearSafeCache() async {
    await _wipe(() async => getApplicationCacheDirectory());
    await _wipe(() async => getTemporaryDirectory());
  }

  static Future<int> _safeSize(Future<Directory> Function() locate) async {
    try {
      return _dirSize(await locate());
    } catch (_) {
      return 0;
    }
  }

  static Future<void> _wipe(Future<Directory> Function() locate) async {
    try {
      final dir = await locate();
      if (!dir.existsSync()) {
        return;
      }
      for (final entity in dir.listSync()) {
        try {
          entity.deleteSync(recursive: true);
        } catch (_) {}
      }
    } catch (_) {}
  }

  static int _dirSize(Directory dir) {
    if (!dir.existsSync()) {
      return 0;
    }
    var total = 0;
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += entity.lengthSync();
        } catch (_) {}
      }
    }
    return total;
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}
