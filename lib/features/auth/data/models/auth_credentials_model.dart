/// Access/refresh credentials returned by the auth API.
///
/// Data-layer only. Do not map into presentation entities or log this object.
final class AuthCredentialsModel {
  const AuthCredentialsModel({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    this.expiresIn,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int? expiresIn;

  factory AuthCredentialsModel.fromJson(Map<String, dynamic> json) {
    return AuthCredentialsModel(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String? ?? 'Bearer',
      expiresIn: json['expires_in'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_type': tokenType,
      if (expiresIn != null) 'expires_in': expiresIn,
    };
  }

  @override
  String toString() => 'AuthCredentialsModel(redacted)';
}
