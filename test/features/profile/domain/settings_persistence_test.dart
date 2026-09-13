import 'package:flutter_test/flutter_test.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/core/storage/local_app_data.dart';
import 'package:seyra/features/profile/data/datasources/mock_profile_data_source.dart';
import 'package:seyra/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:seyra/features/profile/domain/entities/user_profile.dart';
import 'package:seyra/features/profile/domain/usecases/change_username_use_case.dart';
import 'package:seyra/features/profile/domain/usecases/update_preferences_use_case.dart';

void main() {
  test('change username rejects invalid names', () async {
    final useCase = ChangeUsernameUseCase(
      ProfileRepositoryImpl(dataSource: MockProfileDataSource()),
    );
    final result = await useCase('ab');
    expect(result, isA<FailureResult<UserProfile>>());
  });

  test('change username persists on the mock store', () async {
    final source = MockProfileDataSource();
    await source.watchProfile(userId: 'usr_1', username: 'ada').first;
    final useCase = ChangeUsernameUseCase(
      ProfileRepositoryImpl(dataSource: source),
    );
    final result = await useCase('ada_prime');
    expect((result as Success<UserProfile>).value.username, 'ada_prime');
  });

  test('appearance preference is stored on the mock data source', () async {
    final repo = ProfileRepositoryImpl(dataSource: MockProfileDataSource());
    final useCase = UpdatePreferencesUseCase(repo);
    final result = await useCase(
      const UserPreferences(appearance: AppearancePreference.dark),
    );
    expect(
      (result as Success<UserPreferences>).value.appearance,
      AppearancePreference.dark,
    );
    expect(
      (await repo.watchPreferences().first).appearance,
      AppearancePreference.dark,
    );
  });

  test('storage formatter is an estimate label not a fake constant', () {
    expect(LocalAppData.formatBytes(512), '512 B');
    expect(LocalAppData.formatBytes(2048), '2.0 KB');
  });
}
