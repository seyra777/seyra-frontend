import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:seyra/core/storage/secure_storage.dart';

/// Safe decrypt failure. Never include plaintext, keys, or ciphertext.
final class E2eDecryptException implements Exception {
  const E2eDecryptException(this.code);

  final String code;

  static E2eDecryptException fromError(Object error, {required bool hasSession}) {
    final name = error.runtimeType.toString();
    if (name.contains('NoSession')) {
      return const E2eDecryptException('e2e.no_session');
    }
    if (name.contains('UntrustedIdentity')) {
      return const E2eDecryptException('e2e.untrusted_identity');
    }
    if (name.contains('DuplicateMessage')) {
      return const E2eDecryptException('e2e.duplicate');
    }
    if (name.contains('InvalidMessage') ||
        name.contains('InvalidKey') ||
        name.contains('LegacyMessage') ||
        name.contains('FormatException')) {
      return const E2eDecryptException('e2e.invalid_ciphertext');
    }
    if (!hasSession) {
      return const E2eDecryptException('e2e.no_session');
    }
    return const E2eDecryptException('e2e.protocol_mismatch');
  }

  @override
  String toString() => 'E2eDecryptException($code)';
}

/// Signal Protocol (X3DH + Double Ratchet) via libsignal_protocol_dart.
/// Private identity material stays in SecureStorage and is never POSTed.
/// Session/ratchet state, one-time prekeys, and signed prekeys are also
/// persisted in SecureStorage so encrypt/decrypt survives process death.
final class SignalE2eService {
  SignalE2eService(this._storage, {this.userId = ''});

  final SecureStorage _storage;
  final String userId;
  InMemorySignalProtocolStore? _store;
  int _registrationId = 0;
  String _deviceId = '1';
  var _identityWasNew = false;
  /// Serializes all store-mutating crypto so concurrent WS/history/send
  /// paths cannot race the Double Ratchet or overwrite `_persistState`.
  Future<void> _opChain = Future<void>.value();
  /// Ciphertext → plaintext so a second decrypt of the same blob (WS+history)
  /// returns the body instead of DuplicateMessage / placeholder.
  final _plaintextByCipher = <String, String>{};

  String get deviceId => _deviceId;

  Future<T> _serialized<T>(Future<T> Function() action) {
    final done = Completer<T>();
    _opChain = _opChain.then((_) async {
      try {
        done.complete(await action());
      } catch (error, stack) {
        done.completeError(error, stack);
      }
    });
    // Keep the chain alive after failures so later ops still run.
    _opChain = _opChain.catchError((_) {});
    return done.future;
  }

  Future<void> install() async {
    if (_store != null) {
      return;
    }
    var existing = await _storage.read(_identityKey);
    if ((existing == null || existing.isEmpty) && userId.isNotEmpty) {
      final owner = await _storage.read('seyra.e2e.owner');
      if (owner == null || owner == userId) {
        existing = await _storage.read('seyra.e2e.identity');
        if (existing != null && existing.isNotEmpty) {
          await _storage.write(key: _identityKey, value: existing);
          await _storage.write(
            key: _regKey,
            value: await _storage.read('seyra.e2e.registration') ?? '1',
          );
          await _storage.write(
            key: _deviceKey,
            value: await _storage.read('seyra.e2e.device') ?? '1',
          );
          final legacyState = await _storage.read('seyra.e2e.protocol_state');
          if (legacyState != null && legacyState.isNotEmpty) {
            await _storage.write(key: _stateKey, value: legacyState);
          }
          await _storage.write(key: 'seyra.e2e.owner', value: userId);
        }
      }
    }
    final IdentityKeyPair identity;
    if (existing != null && existing.isNotEmpty) {
      identity = IdentityKeyPair.fromSerialized(base64Decode(existing));
      _registrationId = int.parse(await _storage.read(_regKey) ?? '1');
      _deviceId = await _storage.read(_deviceKey) ?? '1';
      _identityWasNew = false;
    } else {
      _identityWasNew = true;
      identity = generateIdentityKeyPair();
      _registrationId = generateRegistrationId(false);
      _deviceId = '1';
      await _storage.write(
        key: _identityKey,
        value: base64Encode(identity.serialize()),
      );
      await _storage.write(key: _regKey, value: '$_registrationId');
      await _storage.write(key: _deviceKey, value: _deviceId);
      if (userId.isNotEmpty) {
        final owner = await _storage.read('seyra.e2e.owner');
        if (owner == null) {
          await _storage.write(key: 'seyra.e2e.owner', value: userId);
        }
      }
    }
    _store = InMemorySignalProtocolStore(identity, _registrationId);
    await _restoreState();
  }

  Future<Map<String, dynamic>> exportPublicBundle() async {
    return _serialized(() async {
      await install();
      final store = _store!;
      final identity = await store.getIdentityKeyPair();
      late final SignedPreKeyRecord signed;
      if (await store.containsSignedPreKey(1)) {
        signed = await store.loadSignedPreKey(1);
      } else {
        signed = generateSignedPreKey(identity, 1);
        await store.storeSignedPreKey(signed.id, signed);
      }
      if (store.preKeyStore.store.isEmpty && !_identityWasNew) {
        await _restoreState();
      }
      if (store.preKeyStore.store.length < 20) {
        var nextId = 1;
        for (final id in store.preKeyStore.store.keys) {
          if (id >= nextId) {
            nextId = id + 1;
          }
        }
        if (nextId == 1 && !_identityWasNew) {
          nextId = 1000;
        }
        final need = 80 - store.preKeyStore.store.length;
        if (need > 0) {
          final preKeys = generatePreKeys(nextId, need);
          for (final key in preKeys) {
            await store.storePreKey(key.id, key);
          }
        }
      }
      await _persistState();
      final prekeys = <Map<String, dynamic>>[];
      for (final id in store.preKeyStore.store.keys.toList()..sort()) {
        final record = await store.loadPreKey(id);
        prekeys.add({
          'key_id': record.id,
          'public_key': base64Encode(record.getKeyPair().publicKey.serialize()),
        });
      }
      return {
        'device_id': _deviceId,
        'registration_id': _registrationId,
        'identity_public': base64Encode(identity.getPublicKey().serialize()),
        'signed_prekey_id': signed.id,
        'signed_prekey_public':
            base64Encode(signed.getKeyPair().publicKey.serialize()),
        'signed_prekey_sig': base64Encode(signed.signature),
        'prekeys': prekeys,
      };
    });
  }

  Future<bool> hasSession(String peerUserId) async {
    return _serialized(() async {
      await install();
      return _store!.containsSession(SignalProtocolAddress(peerUserId, 1));
    });
  }

  Future<void> processRemoteBundle({
    required String userId,
    required Map<String, dynamic> bundle,
  }) async {
    await _serialized(() async {
      await install();
      final address = SignalProtocolAddress(userId, 1);
      final identityPub = IdentityKey.fromBytes(
        base64Decode(bundle['identity_public'] as String),
        0,
      );
      final signedPub = Curve.decodePoint(
        base64Decode(bundle['signed_prekey_public'] as String),
        0,
      );
      ECPublicKey? oneTime;
      final ot = bundle['one_time_prekey_public'] as String?;
      if (ot != null && ot.isNotEmpty) {
        oneTime = Curve.decodePoint(base64Decode(ot), 0);
      }
      final preKeyId =
          oneTime == null ? null : _jsonInt(bundle['one_time_prekey_id']);
      final preKeyBundle = PreKeyBundle(
        _jsonInt(bundle['registration_id']),
        1,
        preKeyId,
        oneTime,
        _jsonInt(bundle['signed_prekey_id']),
        signedPub,
        base64Decode(bundle['signed_prekey_sig'] as String),
        identityPub,
      );
      final builder = SessionBuilder.fromSignalStore(_store!, address);
      try {
        await builder.processPreKeyBundle(preKeyBundle);
      } on UntrustedIdentityException {
        await _store!.saveIdentity(address, identityPub);
        await _store!.deleteSession(address);
        await builder.processPreKeyBundle(preKeyBundle);
      }
      await _persistState();
    });
  }

  Future<bool> trustedIdentityMatches(
    String peerUserId,
    String identityPublicB64,
  ) async {
    return _serialized(() async {
      await install();
      try {
        final existing = await _store!.getIdentity(
          SignalProtocolAddress(peerUserId, 1),
        );
        if (existing == null) {
          return false;
        }
        return base64Encode(existing.serialize()) == identityPublicB64;
      } catch (_) {
        return false;
      }
    });
  }

  Future<void> replaceRemoteSession(String peerUserId) async {
    await _serialized(() async {
      await install();
      final address = SignalProtocolAddress(peerUserId, 1);
      await _store!.deleteSession(address);
      await _persistState();
    });
  }

  Future<String?> encrypt({
    required String peerUserId,
    required String plaintext,
  }) async {
    return _serialized(() async {
      await install();
      final address = SignalProtocolAddress(peerUserId, 1);
      if (!await _store!.containsSession(address)) {
        return null;
      }
      final cipher = SessionCipher.fromStore(_store!, address);
      final message = await cipher.encrypt(
        Uint8List.fromList(utf8.encode(plaintext)),
      );
      await _persistState();
      return base64Encode(_wrap(message));
    });
  }

  Future<String> decrypt({
    required String peerUserId,
    required String ciphertext,
  }) async {
    return _serialized(() async {
      await install();
      final hit = _plaintextByCipher[ciphertext];
      if (hit != null && hit.isNotEmpty) {
        return hit;
      }
      final address = SignalProtocolAddress(peerUserId, 1);
      final hasSession = await _store!.containsSession(address);
      final raw = base64Decode(ciphertext);
      final parsed = _unwrap(raw);
      Future<Uint8List> open() async {
        final cipher = SessionCipher.fromStore(_store!, address);
        if (parsed.type == CiphertextMessage.prekeyType) {
          return cipher.decrypt(PreKeySignalMessage(parsed.body));
        }
        return cipher.decryptFromSignal(
          SignalMessage.fromSerialized(parsed.body),
        );
      }

      try {
        final bytes = await open();
        final plain = utf8.decode(bytes);
        _rememberCipherPlaintext(ciphertext, plain);
        await _persistState();
        return plain;
      } catch (error) {
        final mapped = E2eDecryptException.fromError(
          error,
          hasSession: hasSession,
        );
        if (mapped.code == 'e2e.duplicate') {
          final cached = _plaintextByCipher[ciphertext];
          if (cached != null && cached.isNotEmpty) {
            return cached;
          }
        }
        throw mapped;
      }
    });
  }

  void _rememberCipherPlaintext(String ciphertext, String plaintext) {
    if (ciphertext.isEmpty || plaintext.isEmpty) {
      return;
    }
    _plaintextByCipher[ciphertext] = plaintext;
    while (_plaintextByCipher.length > 500) {
      _plaintextByCipher.remove(_plaintextByCipher.keys.first);
    }
  }

  /// Envelope: `0x01 | type | Signal serialize()`. Legacy blobs have no prefix.
  static Uint8List _wrap(CiphertextMessage message) {
    return Uint8List.fromList(<int>[
      1,
      message.getType(),
      ...message.serialize(),
    ]);
  }

  static ({int type, Uint8List body}) _unwrap(Uint8List raw) {
    if (raw.length >= 3 &&
        raw[0] == 1 &&
        (raw[1] == CiphertextMessage.whisperType ||
            raw[1] == CiphertextMessage.prekeyType)) {
      return (type: raw[1], body: raw.sublist(2));
    }
    try {
      PreKeySignalMessage(raw);
      return (type: CiphertextMessage.prekeyType, body: raw);
    } catch (_) {
      return (type: CiphertextMessage.whisperType, body: raw);
    }
  }

  static int _jsonInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value') ?? 0;
  }

  Future<void> _persistState() async {
    final store = _store;
    if (store == null) {
      return;
    }
    final sessions = <String, String>{};
    store.sessionStore.sessions.forEach((address, bytes) {
      sessions['${address.getName()}:${address.getDeviceId()}'] =
          base64Encode(bytes);
    });
    final prekeys = <String, String>{};
    store.preKeyStore.store.forEach((id, bytes) {
      prekeys['$id'] = base64Encode(bytes);
    });
    final signed = <String, String>{};
    store.signedPreKeyStore.store.forEach((id, bytes) {
      signed['$id'] = base64Encode(bytes);
    });
    final trusted = <String, String>{};
    final addresses = {
      ...store.sessionStore.sessions.keys,
    };
    for (final address in addresses) {
      try {
        final identity = await store.getIdentity(address);
        if (identity != null) {
          trusted['${address.getName()}:${address.getDeviceId()}'] =
              base64Encode(identity.serialize());
        }
      } catch (_) {}
    }
    try {
      await _storage.write(
        key: _stateKey,
        value: jsonEncode({
          'sessions': sessions,
          'prekeys': prekeys,
          'signed': signed,
          'trusted': trusted,
        }),
      );
    } catch (_) {}
  }

  Future<void> _restoreState() async {
    final store = _store!;
    final raw = await _storage.read(_stateKey);
    if (raw == null || raw.isEmpty) {
      return;
    }
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final prekeys = map['prekeys'] as Map<String, dynamic>? ?? {};
    for (final entry in prekeys.entries) {
      final id = int.tryParse(entry.key);
      final value = entry.value as String?;
      if (id == null || value == null) {
        continue;
      }
      store.preKeyStore.store[id] = base64Decode(value);
    }
    final signed = map['signed'] as Map<String, dynamic>? ?? {};
    for (final entry in signed.entries) {
      final id = int.tryParse(entry.key);
      final value = entry.value as String?;
      if (id == null || value == null) {
        continue;
      }
      store.signedPreKeyStore.store[id] = base64Decode(value);
    }
    final trusted = map['trusted'] as Map<String, dynamic>? ?? {};
    for (final entry in trusted.entries) {
      final parts = entry.key.split(':');
      final value = entry.value as String?;
      if (parts.length != 2 || value == null) {
        continue;
      }
      final deviceId = int.tryParse(parts[1]) ?? 1;
      await store.saveIdentity(
        SignalProtocolAddress(parts[0], deviceId),
        IdentityKey.fromBytes(base64Decode(value), 0),
      );
    }
    final sessions = map['sessions'] as Map<String, dynamic>? ?? {};
    for (final entry in sessions.entries) {
      final parts = entry.key.split(':');
      final value = entry.value as String?;
      if (parts.length != 2 || value == null) {
        continue;
      }
      final deviceId = int.tryParse(parts[1]) ?? 1;
      store.sessionStore.sessions[SignalProtocolAddress(parts[0], deviceId)] =
          base64Decode(value);
    }
  }

  String get _identityKey => _scoped('seyra.e2e.identity');
  String get _regKey => _scoped('seyra.e2e.registration');
  String get _deviceKey => _scoped('seyra.e2e.device');
  String get _stateKey => _scoped('seyra.e2e.protocol_state');

  String _scoped(String base) {
    if (userId.isEmpty) {
      return base;
    }
    return '$base.$userId';
  }
}
