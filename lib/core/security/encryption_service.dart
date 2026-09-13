/// Future encryption boundary.
///
/// Algorithm and key-management choices are deferred.
/// UI and feature presentation layers must never implement crypto.
/// Authentication credentials are not E2E keys and must not be mixed with them.
abstract interface class EncryptionService {}
