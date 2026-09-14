import 'dart:async';
import 'dart:typed_data';

import 'package:seyra/core/crypto/backup_crypto.dart';
import 'package:seyra/core/crypto/key_backup_service.dart';
import 'package:seyra/core/services/backup_api_service.dart';
import 'package:seyra/core/storage/secure_storage.dart';

typedef BackupRestoreCallback = Future<void> Function(String userId);

/// Orchestrates local encryption and remote backup storage.
///
/// Chat message bodies stay on the server. This backup restores Signal keys so
/// those ciphertext rows become readable again after reinstall.
final class BackupService {
  BackupService({
    required KeyBackupService keyBackup,
    required BackupApiService api,
    required SecureStorage secureStorage,
    this.onRestored,
  })  : _keyBackup = keyBackup,
        _api = api,
        _storage = secureStorage;

  final KeyBackupService _keyBackup;
  final BackupApiService _api;
  final SecureStorage _storage;
  final BackupRestoreCallback? onRestored;
  Timer? _uploadDebounce;
  var _uploadInFlight = false;
  var _uploadAgain = false;

  /// Derive a backup passphrase from the account password (never uploaded).
  static String accountPassphrase({
    required String userId,
    required String password,
  }) {
    return 'seyra.account.v1|$userId|$password';
  }

  String _secretKey(String userId) => 'seyra.backup.account_secret.$userId';

  Future<void> rememberAccountSecret({
    required String userId,
    required String password,
  }) {
    return _storage.write(
      key: _secretKey(userId),
      value: accountPassphrase(userId: userId, password: password),
    );
  }

  Future<String?> _storedSecret(String userId) =>
      _storage.read(_secretKey(userId));

  /// Called right after login/register with the account password.
  /// Restores keys when local state is missing and a cloud backup exists.
  Future<bool> syncAfterPasswordAuth({
    required String userId,
    required String password,
  }) async {
    if (userId.isEmpty || password.isEmpty) {
      return false;
    }
    await rememberAccountSecret(userId: userId, password: password);
    final passphrase = accountPassphrase(userId: userId, password: password);

    final hasLocal = await _keyBackup.hasLocalKeys(userId);
    if (!hasLocal) {
      final hasRemote = await hasRemoteBackup();
      if (hasRemote) {
        await restoreBackup(userId: userId, passphrase: passphrase);
        return true;
      }
    }

    // Fresh device with no backup yet, or keys already present: upload later
    // once Signal material exists (see [tryUploadWithStoredSecret]).
    if (hasLocal) {
      try {
        await uploadBackup(userId: userId, passphrase: passphrase);
      } catch (_) {}
    }
    return false;
  }

  /// Background upload using the secret remembered at login (same device).
  /// Debounced so rapid hydrates do not flood `/v1/backup`.
  Future<void> tryUploadWithStoredSecret(String userId) async {
    if (userId.isEmpty) {
      return;
    }
    _uploadDebounce?.cancel();
    _uploadDebounce = Timer(const Duration(milliseconds: 500), () {
      unawaited(_uploadWithStoredSecretNow(userId));
    });
  }

  /// Cancel debounce and upload now — call after a successful send so the
  /// outbox is in cloud backup before the user can uninstall.
  Future<void> flushUploadWithStoredSecret(String userId) async {
    if (userId.isEmpty) {
      return;
    }
    _uploadDebounce?.cancel();
    _uploadDebounce = null;
    await _uploadWithStoredSecretNow(userId);
  }

  Future<void> _uploadWithStoredSecretNow(String userId) async {
    if (_uploadInFlight) {
      _uploadAgain = true;
      return;
    }
    if (!await _keyBackup.hasLocalKeys(userId)) {
      return;
    }
    final secret = await _storedSecret(userId);
    if (secret == null || secret.isEmpty) {
      return;
    }
    _uploadInFlight = true;
    try {
      do {
        _uploadAgain = false;
        try {
          await uploadBackup(userId: userId, passphrase: secret);
        } catch (_) {}
      } while (_uploadAgain);
    } finally {
      _uploadInFlight = false;
    }
  }

  Future<DateTime?> uploadBackup({
    required String userId,
    required String passphrase,
  }) async {
    final packageBytes = await _keyBackup.exportBytes(userId);
    final encrypted = await BackupCrypto.encrypt(
      plaintext: packageBytes,
      passphrase: passphrase,
    );
    await _api.uploadEncryptedBlob(encrypted);
    final snapshot = await _api.downloadEncryptedBlob();
    return snapshot.updatedAt;
  }

  Future<void> restoreBackup({
    required String userId,
    required String passphrase,
  }) async {
    final snapshot = await _api.downloadEncryptedBlob();
    final opened = await BackupCrypto.decrypt(
      envelopeBytes: snapshot.encryptedBlob,
      passphrase: passphrase,
    );
    await _keyBackup.importBytes(userId: userId, bytes: opened);
    await onRestored?.call(userId);
  }

  Future<bool> hasRemoteBackup() => _api.hasRemoteBackup();

  Future<bool> hasLocalKeys(String userId) => _keyBackup.hasLocalKeys(userId);

  Future<void> deleteRemoteBackup() => _api.deleteRemoteBackup();

  Future<Uint8List> exportLocalEncryptedBackup({
    required String userId,
    required String passphrase,
  }) async {
    final packageBytes = await _keyBackup.exportBytes(userId);
    return BackupCrypto.encrypt(
      plaintext: packageBytes,
      passphrase: passphrase,
    );
  }

  Future<void> importLocalEncryptedBackup({
    required String userId,
    required Uint8List encryptedBlob,
    required String passphrase,
  }) async {
    final opened = await BackupCrypto.decrypt(
      envelopeBytes: encryptedBlob,
      passphrase: passphrase,
    );
    await _keyBackup.importBytes(userId: userId, bytes: opened);
    await onRestored?.call(userId);
  }
}
