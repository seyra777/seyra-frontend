/// Sensitive persistence boundary (tokens, keys).
///
/// Auth access/refresh credentials must use this API when persistence is added.
/// No platform secure-storage implementation is wired yet.
/// Do not store secrets in [LocalStorage].
abstract interface class SecureStorage {
  Future<void> write({required String key, required String value});

  Future<String?> read(String key);

  Future<void> delete(String key);

  Future<void> deleteAll();
}
