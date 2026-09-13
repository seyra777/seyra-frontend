/// Provider-agnostic auth paths. A future transport maps these to real URLs.
abstract final class AuthApiEndpoints {
  static const register = '/v1/auth/register';
  static const login = '/v1/auth/login';
  static const logout = '/v1/auth/logout';
  static const session = '/v1/auth/session';
  static const refresh = '/v1/auth/refresh';
  static const deleteAccount = '/v1/auth/account/delete';
  static const currentUser = '/v1/users/me';
}
