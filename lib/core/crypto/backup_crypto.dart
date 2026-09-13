import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Passphrase-based authenticated encryption for E2E backup blobs.
///
/// The server only ever receives the outer ciphertext envelope.
final class BackupCrypto {
  BackupCrypto._();

  static const format = 'seyra-backup-v1';
  static const iterations = 120000;
  static const _saltLength = 16;
  static const _nonceLength = 12;

  static final AesGcm _aes = AesGcm.with256bits();
  static final Pbkdf2 _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  );

  static Future<Uint8List> encrypt({
    required Uint8List plaintext,
    required String passphrase,
  }) async {
    final salt = _randomBytes(_saltLength);
    final nonce = _randomBytes(_nonceLength);
    final secretKey = await _deriveKey(passphrase, salt);
    final box = await _aes.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );
    final envelope = jsonEncode({
      'format': format,
      'kdf': 'pbkdf2-sha256',
      'iterations': iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode([...box.cipherText, ...box.mac.bytes]),
    });
    return Uint8List.fromList(utf8.encode(envelope));
  }

  static Future<Uint8List> decrypt({
    required Uint8List envelopeBytes,
    required String passphrase,
  }) async {
    final map = jsonDecode(utf8.decode(envelopeBytes)) as Map<String, dynamic>;
    if (map['format'] != format) {
      throw const FormatException('unsupported backup format');
    }
    final salt = base64Decode(map['salt'] as String);
    final nonce = base64Decode(map['nonce'] as String);
    final raw = base64Decode(map['ciphertext'] as String);
    if (raw.length < 16) {
      throw const FormatException('truncated backup ciphertext');
    }
    final macStart = raw.length - 16;
    final box = SecretBox(
      raw.sublist(0, macStart),
      nonce: nonce,
      mac: Mac(raw.sublist(macStart)),
    );
    final secretKey = await _deriveKey(passphrase, salt);
    try {
      final opened = await _aes.decrypt(box, secretKey: secretKey);
      return Uint8List.fromList(opened);
    } on SecretBoxAuthenticationError {
      throw const FormatException('invalid backup passphrase');
    }
  }

  static Future<SecretKey> _deriveKey(String passphrase, List<int> salt) {
    return _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}
