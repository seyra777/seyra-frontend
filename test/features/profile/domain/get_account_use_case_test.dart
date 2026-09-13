import 'package:flutter_test/flutter_test.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/auth/data/datasources/mock_auth_remote_data_source.dart';
import 'package:seyra/features/profile/data/repositories/account_repository_impl.dart';
import 'package:seyra/features/profile/domain/entities/account.dart';
import 'package:seyra/features/profile/domain/usecases/get_account_use_case.dart';

void main() {
  test('loads the authenticated account after register', () async {
    final remote = MockAuthRemoteDataSource();
    final useCase = GetAccountUseCase(
      AccountRepositoryImpl(remoteDataSource: remote),
    );

    await remote.register(username: 'ada', password: 'secret');
    final result = await useCase();
    final account = (result as Success<Account>).value;

    expect(account.username, 'ada');
    expect(account.id, isNotEmpty);
  });
}
