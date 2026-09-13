import 'dart:convert';
import 'dart:io';

import 'package:seyra/core/storage/secure_storage.dart';

/// Large Signal blobs do not fit Android Keystore RSA wraps used by the
/// default [FlutterSecureStorage] backend. E2E keys are mirrored into an
/// app-private directory so a rebuild/process restart can restore sessions.
final class DurableSecureStorage implements SecureStorage {
  DurableSecureStorage({
    required SecureStorage inner,
    required Directory directory,
  }) : _inner = inner,
       _directory = directory;

  final SecureStorage _inner;
  final Directory _directory;

  @override
  Future<void> write({required String key, required String value}) async {
    if (_isDurableKey(key)) {
      await _writeFile(key, value);
    }
    try {
      await _inner.write(key: key, value: value);
    } catch (_) {
      if (!_isDurableKey(key)) {
        rethrow;
      }
    }
  }

  @override
  Future<String?> read(String key) async {
    if (_isDurableKey(key)) {
      final fromFile = await _readFile(key);
      if (fromFile != null && fromFile.isNotEmpty) {
        return fromFile;
      }
    }
    return _inner.read(key);
  }

  @override
  Future<void> delete(String key) async {
    await _deleteFile(key);
    await _inner.delete(key);
  }

  @override
  Future<void> deleteAll() async {
    if (_directory.existsSync()) {
      await _directory.delete(recursive: true);
    }
    await _inner.deleteAll();
  }

  static bool _isDurableKey(String key) => key.contains('seyra.e2e');

  Future<void> _ensureDir() async {
    if (!_directory.existsSync()) {
      await _directory.create(recursive: true);
    }
  }

  File _fileFor(String key) {
    final name = base64Url.encode(utf8.encode(key));
    return File('${_directory.path}${Platform.pathSeparator}$name');
  }

  Future<void> _writeFile(String key, String value) async {
    await _ensureDir();
    await _fileFor(key).writeAsString(value, flush: true);
  }

  Future<String?> _readFile(String key) async {
    final file = _fileFor(key);
    if (!file.existsSync()) {
      return null;
    }
    return file.readAsString();
  }

  Future<void> _deleteFile(String key) async {
    final file = _fileFor(key);
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
