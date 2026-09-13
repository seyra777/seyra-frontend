import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seyra/core/storage/durable_secure_storage.dart';
import 'package:seyra/core/storage/memory_secure_storage.dart';

void main() {
  test('restores e2e blobs from files after inner storage is wiped', () async {
    final dir = await Directory.systemTemp.createTemp('seyra_e2e_');
    addTearDown(() async {
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    });
    final inner = MemorySecureStorage();
    final storage = DurableSecureStorage(inner: inner, directory: dir);
    await storage.write(key: 'seyra.e2e.protocol_state.usr_a', value: 'sessions');
    await inner.deleteAll();
    expect(
      await storage.read('seyra.e2e.protocol_state.usr_a'),
      'sessions',
    );
  });

  test('keeps non-e2e keys on the inner store only', () async {
    final dir = await Directory.systemTemp.createTemp('seyra_tok_');
    addTearDown(() async {
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    });
    final inner = MemorySecureStorage();
    final storage = DurableSecureStorage(inner: inner, directory: dir);
    await storage.write(key: 'access_token', value: 'tok');
    expect(dir.listSync(), isEmpty);
    expect(await storage.read('access_token'), 'tok');
  });
}
