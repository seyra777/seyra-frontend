import 'package:flutter_test/flutter_test.dart';
import 'package:seyra/core/storage/memory_secure_storage.dart';
import 'package:seyra/features/chat/data/crypto/signal_e2e_service.dart';

void main() {
  Future<({SignalE2eService alice, SignalE2eService bob})> paired() async {
    final alice = SignalE2eService(MemorySecureStorage(), userId: 'alice');
    final bob = SignalE2eService(MemorySecureStorage(), userId: 'bob');
    await alice.install();
    await bob.install();
    final bobBundle = await bob.exportPublicBundle();
    // Mimic server OTP consumption: use first published prekey.
    final prekeys = (bobBundle['prekeys'] as List).cast<Map<String, dynamic>>();
    expect(prekeys, isNotEmpty);
    await alice.processRemoteBundle(
      userId: 'bob',
      bundle: {
        ...bobBundle,
        'one_time_prekey_id': prekeys.first['key_id'],
        'one_time_prekey_public': prekeys.first['public_key'],
      },
    );
    return (alice: alice, bob: bob);
  }

  test('round-trip encrypt/decrypt for a new session', () async {
    final pair = await paired();
    final cipher = await pair.alice.encrypt(
      peerUserId: 'bob',
      plaintext: 'hello bob',
    );
    expect(cipher, isNotNull);
    // Bob has no session until he decrypts Alice's PreKey message.
    final plain = await pair.bob.decrypt(
      peerUserId: 'alice',
      ciphertext: cipher!,
    );
    expect(plain, 'hello bob');
  });

  test('duplicate decrypt returns cached plaintext instead of failing', () async {
    final pair = await paired();
    final cipher = await pair.alice.encrypt(
      peerUserId: 'bob',
      plaintext: 'once',
    );
    final first = await pair.bob.decrypt(
      peerUserId: 'alice',
      ciphertext: cipher!,
    );
    final second = await pair.bob.decrypt(
      peerUserId: 'alice',
      ciphertext: cipher,
    );
    expect(first, 'once');
    expect(second, 'once');
  });

  test('concurrent decrypts of many messages stay consistent', () async {
    final pair = await paired();
    final ciphers = <String>[];
    for (var i = 0; i < 20; i++) {
      final cipher = await pair.alice.encrypt(
        peerUserId: 'bob',
        plaintext: 'msg-$i',
      );
      ciphers.add(cipher!);
    }
    final results = await Future.wait([
      for (var i = 0; i < ciphers.length; i++)
        pair.bob.decrypt(peerUserId: 'alice', ciphertext: ciphers[i]),
    ]);
    expect(results, [for (var i = 0; i < 20; i++) 'msg-$i']);
  });

  test('bidirectional rapid messages decrypt correctly', () async {
    final pair = await paired();
    // Alice opens the session toward Bob; Bob's decrypt establishes his side.
    final open = await pair.alice.encrypt(
      peerUserId: 'bob',
      plaintext: 'open',
    );
    await pair.bob.decrypt(peerUserId: 'alice', ciphertext: open!);
    expect(await pair.bob.hasSession('alice'), isTrue);

    final aToB = <String>[];
    final bToA = <String>[];
    for (var i = 0; i < 10; i++) {
      aToB.add(
        (await pair.alice.encrypt(peerUserId: 'bob', plaintext: 'a-$i'))!,
      );
      bToA.add(
        (await pair.bob.encrypt(peerUserId: 'alice', plaintext: 'b-$i'))!,
      );
    }

    final bobSees = await Future.wait([
      for (final c in aToB) pair.bob.decrypt(peerUserId: 'alice', ciphertext: c),
    ]);
    final aliceSees = await Future.wait([
      for (final c in bToA)
        pair.alice.decrypt(peerUserId: 'bob', ciphertext: c),
    ]);

    expect(bobSees, [for (var i = 0; i < 10; i++) 'a-$i']);
    expect(aliceSees, [for (var i = 0; i < 10; i++) 'b-$i']);
  });

  test('hasSession stays true across encrypt without rebuilding', () async {
    final pair = await paired();
    expect(await pair.alice.hasSession('bob'), isTrue);
    await pair.alice.encrypt(peerUserId: 'bob', plaintext: 'keep');
    expect(await pair.alice.hasSession('bob'), isTrue);
  });
}
