import 'package:flutter_test/flutter_test.dart';
import 'package:seyra/features/auth/data/models/auth_credentials_model.dart';
import 'package:seyra/features/auth/data/models/auth_session_model.dart';
import 'package:seyra/features/auth/data/models/user_model.dart';

void main() {
  const json = {
    'user': {'id': '1', 'username': 'ada', 'password': 'should-be-ignored'},
    'session': {
      'id': 'ses_1',
      'expires_at': '2026-09-07T12:00:00.000Z',
    },
    'credentials': {
      'access_token': 'access-secret',
      'refresh_token': 'refresh-secret',
      'token_type': 'Bearer',
      'expires_in': 3600,
    },
  };

  test('maps API JSON and keeps credentials out of the domain entity', () {
    final model = AuthSessionModel.fromJson(json);
    final entity = model.toEntity();

    expect(entity.user.id, '1');
    expect(entity.user.username, 'ada');
    expect(entity.sessionId, 'ses_1');
    expect(model.credentials?.accessToken, 'access-secret');
    expect(entity.toString().contains('access-secret'), isFalse);
  });

  test('session toJson omits credentials and passwords', () {
    final encoded = AuthSessionModel.fromJson(json).toJson();

    expect(encoded.containsKey('credentials'), isFalse);
    expect(encoded['user'], isNot(contains('password')));
    expect(encoded.toString().contains('access-secret'), isFalse);
  });

  test('user model never serializes a password field', () {
    const user = UserModel(id: '1', username: 'ada');

    expect(user.toJson().containsKey('password'), isFalse);
  });

  test('credentials toString does not include token values', () {
    const credentials = AuthCredentialsModel(
      accessToken: 'access-secret',
      refreshToken: 'refresh-secret',
      tokenType: 'Bearer',
    );

    expect(credentials.toString().contains('access-secret'), isFalse);
    expect(credentials.toString().contains('refresh-secret'), isFalse);
  });
}
