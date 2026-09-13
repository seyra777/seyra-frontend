import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:seyra/core/crypto/backup_crypto.dart';

void main() {
  test('encrypt and decrypt round trip', () async {
    const passphrase = 'test-passphrase-123';
    final plaintext = Uint8List.fromList(utf8.encode('{"version":1}'));
    final encrypted = await BackupCrypto.encrypt(
      plaintext: plaintext,
      passphrase: passphrase,
    );
    final opened = await BackupCrypto.decrypt(
      envelopeBytes: encrypted,
      passphrase: passphrase,
    );
    expect(opened, plaintext);
  });

  test('wrong passphrase fails authentication', () async {
    final encrypted = await BackupCrypto.encrypt(
      plaintext: Uint8List.fromList([1, 2, 3]),
      passphrase: 'correct-passphrase',
    );
    expect(
      () => BackupCrypto.decrypt(
        envelopeBytes: encrypted,
        passphrase: 'wrong-passphrase',
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
