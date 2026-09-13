import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:seyra/features/chat/data/crypto/attachment_aead.dart';
import 'package:seyra/features/chat/data/crypto/group_e2e.dart';

void main() {
  test('AES-GCM round-trips attachment bytes', () async {
    final plain = utf8.encode('seyra-secret-file');
    final sealed = await AttachmentAead.encrypt(plain);
    expect(sealed.bytes, isNot(equals(plain)));
    final out = await AttachmentAead.decrypt(
      key: sealed.key,
      nonce: sealed.nonce,
      bytes: sealed.bytes,
    );
    expect(out, plain);
  });

  test('wrong key fails closed', () async {
    final sealed = await AttachmentAead.encrypt(utf8.encode('x'));
    expect(
      () => AttachmentAead.decrypt(
        key: List<int>.filled(32, 7),
        nonce: sealed.nonce,
        bytes: sealed.bytes,
      ),
      throwsA(isA<Object>()),
    );
  });

  test('group E2E is explicitly unsupported', () {
    expect(GroupE2ePolicy.supported, isFalse);
    expect(GroupE2ePolicy.limitation, contains('homemade'));
  });
}
