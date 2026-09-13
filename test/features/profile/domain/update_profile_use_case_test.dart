import 'package:flutter_test/flutter_test.dart';
import 'package:seyra/core/errors/failures.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/profile/data/datasources/mock_profile_data_source.dart';
import 'package:seyra/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:seyra/features/profile/domain/entities/user_profile.dart';
import 'package:seyra/features/profile/domain/usecases/update_profile_use_case.dart';

void main() {
  late UpdateProfileUseCase useCase;

  setUp(() {
    useCase = UpdateProfileUseCase(
      ProfileRepositoryImpl(dataSource: MockProfileDataSource()),
    );
  });

  test('rejects a blank display name', () async {
    final result = await useCase(
      userId: 'usr_1',
      displayName: '  ',
      bio: 'Hello',
    );

    expect(result, isA<FailureResult<UserProfile>>());
    expect(
      (result as FailureResult<UserProfile>).failure,
      isA<ValidationFailure>(),
    );
  });

  test('saves a trimmed display name locally', () async {
    final result = await useCase(
      userId: 'usr_1',
      displayName: '  Ada Lovelace  ',
      bio: ' Building Seyra ',
    );

    final profile = (result as Success<UserProfile>).value;
    expect(profile.displayName, 'Ada Lovelace');
    expect(profile.bio, 'Building Seyra');
  });
}
