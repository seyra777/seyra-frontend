import 'package:seyra/core/errors/failures.dart';
import 'package:seyra/core/errors/network_failure.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/auth/data/exceptions/auth_remote_exceptions.dart';
import 'package:seyra/features/auth/domain/failures/auth_failures.dart';
import 'package:seyra/features/profile/data/datasources/profile_data_source.dart';
import 'package:seyra/features/profile/domain/entities/user_profile.dart';
import 'package:seyra/features/profile/domain/repositories/profile_repository.dart';

final class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl({required this.dataSource});

  final ProfileDataSource dataSource;

  @override
  Stream<UserProfile> watchProfile({
    required String userId,
    required String username,
  }) {
    return dataSource.watchProfile(userId: userId, username: username);
  }

  @override
  Stream<UserPreferences> watchPreferences() {
    return dataSource.watchPreferences();
  }

  @override
  Future<Result<UserProfile>> updateProfile({
    required String userId,
    required String displayName,
    required String bio,
  }) {
    return _map(
      () => dataSource.updateProfile(
        userId: userId,
        displayName: displayName,
        bio: bio,
      ),
    );
  }

  @override
  Future<Result<UserProfile>> changeUsername(String username) {
    return _map(() => dataSource.changeUsername(username));
  }

  @override
  Future<Result<UserPreferences>> updatePreferences(
    UserPreferences preferences,
  ) {
    return _map(() => dataSource.updatePreferences(preferences));
  }

  @override
  Future<Result<UserProfile>> uploadAvatar({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) {
    return _map(
      () => dataSource.uploadAvatar(
        bytes: bytes,
        filename: filename,
        contentType: contentType,
      ),
    );
  }

  @override
  Future<Result<UserProfile>> removeAvatar() {
    return _map(dataSource.removeAvatar);
  }

  @override
  Future<List<int>?> fetchAvatar(String userId) {
    return dataSource.fetchAvatar(userId);
  }

  @override
  Future<void> reloadRemote() {
    return dataSource.reloadRemote();
  }

  Future<Result<T>> _map<T>(Future<T> Function() action) async {
    try {
      return Success(await action());
    } on AuthRemoteException catch (error) {
      return FailureResult(_mapAuth(error));
    } catch (_) {
      return const FailureResult(UnexpectedFailure());
    }
  }

  Failure _mapAuth(AuthRemoteException error) {
    return switch (error.code) {
      AuthRemoteErrorCode.unavailable => const AuthUnavailableFailure(),
      AuthRemoteErrorCode.invalidCredentials =>
        const InvalidCredentialsFailure(),
      AuthRemoteErrorCode.usernameTaken => const UsernameTakenFailure(),
      AuthRemoteErrorCode.sessionExpired => const SessionExpiredFailure(),
      AuthRemoteErrorCode.unauthorized => const UnauthorizedFailure(),
      AuthRemoteErrorCode.network => const NetworkFailure(),
      AuthRemoteErrorCode.invalidInput =>
        const ValidationFailure('Invalid request'),
    };
  }
}
