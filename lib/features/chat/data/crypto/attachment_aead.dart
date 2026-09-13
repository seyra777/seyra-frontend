import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// AES-256-GCM envelope for attachment bytes.
/// The 32-byte key is delivered inside a Signal-protected 1-to-1 payload,
/// never stored as plaintext on the server.
final class AttachmentAead {
  static final AesGcm _algo = AesGcm.with256bits();

  static Future<AttachmentCiphertext> encrypt(List<int> plaintext) async {
    final secret = await _algo.newSecretKey();
    final nonce = _algo.newNonce();
    final box = await _algo.encrypt(
      plaintext,
      secretKey: secret,
      nonce: nonce,
    );
    final keyBytes = await secret.extractBytes();
    return AttachmentCiphertext(
      key: Uint8List.fromList(keyBytes),
      nonce: Uint8List.fromList(nonce),
      bytes: Uint8List.fromList([...box.cipherText, ...box.mac.bytes]),
    );
  }

  static Future<Uint8List> decrypt({
    required List<int> key,
    required List<int> nonce,
    required List<int> bytes,
  }) async {
    if (bytes.length < 16) {
      throw const FormatException('truncated ciphertext');
    }
    final macStart = bytes.length - 16;
    final box = SecretBox(
      bytes.sublist(0, macStart),
      nonce: nonce,
      mac: Mac(bytes.sublist(macStart)),
    );
    final clear = await _algo.decrypt(
      box,
      secretKey: SecretKey(key),
    );
    return Uint8List.fromList(clear);
  }
}

final class AttachmentCiphertext {
  const AttachmentCiphertext({
    required this.key,
    required this.nonce,
    required this.bytes,
  });

  final Uint8List key;
  final Uint8List nonce;
  final Uint8List bytes;
}
