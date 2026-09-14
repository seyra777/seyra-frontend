import 'package:flutter_test/flutter_test.dart';
import 'package:seyra/core/crypto/key_backup_service.dart';
import 'package:seyra/core/storage/memory_secure_storage.dart';

void main() {
  test('backup package round-trips identity, protocol state, and outbox', () async {
    final storage = MemorySecureStorage();
    const userId = 'usr_ada';
    await storage.write(
      key: 'seyra.e2e.identity.$userId',
      value: 'identity-bytes-b64',
    );
    await storage.write(
      key: 'seyra.e2e.registration.$userId',
      value: '42',
    );
    await storage.write(
      key: 'seyra.e2e.device.$userId',
      value: '1',
    );
    await storage.write(
      key: 'seyra.e2e.protocol_state.$userId',
      value: '{"sessions":{}}',
    );
    await storage.write(
      key: 'seyra.e2e.outbox.$userId',
      value: '{"ids":{"msg_1":"hello from me"},"ciphers":{"cipher_1":"hello from me"}}',
    );

    final service = KeyBackupService(storage);
    final package = await service.exportPackage(userId);
    expect(package['keys'], isA<Map>());
    final keys = Map<String, dynamic>.from(package['keys'] as Map);
    expect(keys['outbox'], contains('hello from me'));
    expect(keys['identity'], 'identity-bytes-b64');

    final fresh = MemorySecureStorage();
    final restored = KeyBackupService(fresh);
    await restored.importPackage(userId: userId, package: package);

    expect(await fresh.read('seyra.e2e.identity.$userId'), 'identity-bytes-b64');
    expect(
      await fresh.read('seyra.e2e.outbox.$userId'),
      contains('hello from me'),
    );
    expect(await restored.hasLocalKeys(userId), isTrue);
  });
}
