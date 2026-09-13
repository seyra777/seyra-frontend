/// Non-sensitive local persistence boundary (UI prefs, caches).
///
/// Never store passwords, tokens, or encryption keys here.
abstract interface class LocalStorage {
  Future<void> write({required String key, required String value});

  Future<String?> read(String key);

  Future<void> delete(String key);

  Future<void> deleteAll();
}
