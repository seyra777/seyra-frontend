import 'package:seyra/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:seyra/features/auth/data/exceptions/auth_remote_exceptions.dart';
import 'package:seyra/features/auth/data/models/auth_credentials_model.dart';
import 'package:seyra/features/auth/data/models/auth_session_model.dart';
import 'package:seyra/features/auth/data/models/current_account_model.dart';
import 'package:seyra/features/auth/data/models/user_model.dart';

/// In-memory auth adapter for the vertical slice.
///
/// Replace this with a real [AuthRemoteDataSource] in [AppDependencies]
/// without changing domain or UI. Passwords stay in this mock only and are
/// never written to SecureStorage or logs.
final class MockAuthRemoteDataSource implements AuthRemoteDataSource {
  MockAuthRemoteDataSource({
    this.latency = Duration.zero,
  });

  final Duration latency;

  final Map<String, String> _passwordsByUsername = <String, String>{};
  final Map<String, String> _idsByUsername = <String, String>{};
  final Map<String, DateTime> _createdAtByUsername = <String, DateTime>{};
  AuthSessionModel? _currentSession;
  int _nextId = 1;

  @override
  Future<AuthSessionModel> login({
    required String username,
    required String password,
  }) async {
    await _wait();
    final key = username.trim();
    final stored = _passwordsByUsername[key];
    if (stored == null || stored != password) {
      throw const AuthRemoteException(AuthRemoteErrorCode.invalidCredentials);
    }
    return _issueSession(key);
  }

  @override
  Future<AuthSessionModel> register({
    required String username,
    required String password,
  }) async {
    await _wait();
    final key = username.trim();
    if (_passwordsByUsername.containsKey(key)) {
      throw const AuthRemoteException(AuthRemoteErrorCode.usernameTaken);
    }
    _passwordsByUsername[key] = password;
    _idsByUsername[key] = 'usr_$_nextId';
    _createdAtByUsername[key] = DateTime.now().toUtc();
    _nextId += 1;
    return _issueSession(key);
  }

  @override
  Future<void> logout() async {
    await _wait();
    _currentSession = null;
  }

  @override
  Future<AuthSessionModel?> restoreSession() async {
    await _wait();
    return _currentSession;
  }

  @override
  Future<AuthSessionModel> refreshSession() async {
    await _wait();
    final session = _currentSession;
    if (session == null) {
      throw const AuthRemoteException(AuthRemoteErrorCode.sessionExpired);
    }
    return _issueSession(session.user.username);
  }

  @override
  Future<void> deleteAccount({required String password}) async {
    await _wait();
    final session = _currentSession;
    if (session == null) {
      throw const AuthRemoteException(AuthRemoteErrorCode.unauthorized);
    }
    final username = session.user.username;
    if (_passwordsByUsername[username] != password) {
      throw const AuthRemoteException(AuthRemoteErrorCode.invalidCredentials);
    }
    _passwordsByUsername.remove(username);
    _idsByUsername.remove(username);
    _createdAtByUsername.remove(username);
    _currentSession = null;
  }

  @override
  Future<CurrentAccountModel> getCurrentAccount() async {
    await _wait();
    final session = _currentSession;
    if (session == null) {
      throw const AuthRemoteException(AuthRemoteErrorCode.unauthorized);
    }
    final username = session.user.username;
    return CurrentAccountModel(
      id: session.user.id,
      username: username,
      createdAt: _createdAtByUsername[username] ?? DateTime.now().toUtc(),
    );
  }

  Future<void> _wait() async {
    if (latency == Duration.zero) {
      return;
    }
    await Future<void>.delayed(latency);
  }

  AuthSessionModel _issueSession(String username) {
    final userId = _idsByUsername[username] ?? 'usr_$_nextId';
    _idsByUsername[username] = userId;
    final session = AuthSessionModel(
      user: UserModel(id: userId, username: username),
      sessionId: 'ses_$_nextId',
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      credentials: AuthCredentialsModel(
        accessToken: 'mock-access-$_nextId',
        refreshToken: 'mock-refresh-$_nextId',
        tokenType: 'Bearer',
        expiresIn: 3600,
      ),
    );
    _nextId += 1;
    _currentSession = session;
    return session;
  }
}
