import 'package:flutter_test/flutter_test.dart';
import 'package:seyra/features/auth/data/models/auth_request_models.dart';

void main() {
  test('password request JSON includes password for transport only', () {
    const request = AuthPasswordRequest(username: 'ada', password: 'secret');

    expect(request.toJson(), {'username': 'ada', 'password': 'secret'});
    expect(request.toString().contains('secret'), isFalse);
  });

  test('delete-account request redacts password in logs', () {
    const request = DeleteAccountRequest(password: 'secret');

    expect(request.toJson(), {'password': 'secret'});
    expect(request.toString().contains('secret'), isFalse);
  });

  test('refresh request redacts the refresh token in logs', () {
    const request = RefreshSessionRequest(refreshToken: 'refresh-secret');

    expect(request.toJson(), {'refresh_token': 'refresh-secret'});
    expect(request.toString().contains('refresh-secret'), isFalse);
  });
}
