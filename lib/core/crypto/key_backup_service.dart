import 'dart:convert';
import 'dart:typed_data';

import 'package:seyra/core/storage/secure_storage.dart';

/// Collects and restores Signal private material from secure storage.
///
/// Private keys never leave this layer in plaintext — callers must encrypt
/// the exported package before upload.
final class KeyBackupService {
  KeyBackupService(this._storage);

  final SecureStorage _storage;

  static const packageVersion = 1;

  Future<bool> hasLocalKeys(String userId) async {
    if (userId.isEmpty) {
      return false;
    }
    final identity = await _storage.read(_scoped('identity', userId));
    final state = await _storage.read(_scoped('protocol_state', userId));
    return identity != null &&
        identity.isNotEmpty &&
        state != null &&
        state.isNotEmpty;
  }

  Future<Map<String, dynamic>> exportPackage(String userId) async {
    if (userId.isEmpty) {
      throw StateError('userId required');
    }
    final keys = await _readScopedKeys(userId);
    if (keys['identity'] == null || keys['protocol_state'] == null) {
      throw StateError('no E2E keys to back up');
    }
    return {
      'version': packageVersion,
      'userId': userId,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'keys': keys,
    };
  }

  Future<void> importPackage({
    required String userId,
    required Map<String, dynamic> package,
  }) async {
    if (userId.isEmpty) {
      throw StateError('userId required');
    }
    final version = package['version'];
    if (version != packageVersion) {
      throw FormatException('unsupported backup version: $version');
    }
    final owner = package['userId'] as String? ?? '';
    if (owner.isNotEmpty && owner != userId) {
      throw FormatException('backup belongs to another account');
    }
    final keys = package['keys'];
    if (keys is! Map) {
      throw const FormatException('missing keys');
    }
    await _writeScopedKeys(userId, Map<String, String>.from(keys));
  }

  Future<Map<String, String>> _readScopedKeys(String userId) async {
    final out = <String, String>{};
    for (final name in _keyNames) {
      final value = await _storage.read(_scoped(name, userId));
      if (value != null && value.isNotEmpty) {
        out[name] = value;
      }
    }
    final owner = await _storage.read('seyra.e2e.owner');
    if (owner != null && owner.isNotEmpty) {
      out['owner'] = owner;
    }
    return out;
  }

  Future<void> _writeScopedKeys(String userId, Map<String, String> keys) async {
    for (final name in _keyNames) {
      final value = keys[name];
      if (value == null || value.isEmpty) {
        continue;
      }
      await _storage.write(key: _scoped(name, userId), value: value);
    }
    await _storage.write(key: 'seyra.e2e.owner', value: userId);
  }

  Future<Uint8List> exportBytes(String userId) async {
    final package = await exportPackage(userId);
    return Uint8List.fromList(utf8.encode(jsonEncode(package)));
  }

  Future<void> importBytes({
    required String userId,
    required List<int> bytes,
  }) async {
    final package = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    await importPackage(userId: userId, package: package);
  }

  static const _keyNames = [
    'identity',
    'registration',
    'device',
    'protocol_state',
    'outbox',
  ];

  String _scoped(String name, String userId) => 'seyra.e2e.$name.$userId';
}
