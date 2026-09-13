enum AppEnvironment {
  development,
  staging,
  production,
}

enum AuthBackendMode {
  mock,
  http,
}

/// Runtime backend configuration. Secrets must not be stored here.
///
/// Set at build time:
/// `--dart-define=SEYRA_ENV=production`
/// `--dart-define=SEYRA_API_BASE_URL=https://api.example.invalid`
/// `--dart-define=SEYRA_AUTH_MODE=http` (or `mock` for the in-memory demo)
final class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    this.authBackendMode = AuthBackendMode.http,
  });

  final AppEnvironment environment;
  final String apiBaseUrl;
  final AuthBackendMode authBackendMode;

  /// Public API (IONOS / epheverisme.art).
  /// Override with `--dart-define=SEYRA_API_BASE_URL=https://…`
  static const defaultDevelopmentBaseUrl = 'https://epheverisme.art';

  /// Flutter web UI origin (only needed for web + CORS on the API).
  /// `flutter run -d web-server --web-hostname 0.0.0.0 --web-port 5000`
  static const defaultDevelopmentWebHost = 'http://127.0.0.1:5000';
  static const defaultDevelopmentWebPort = 5000;
  static const defaultDevelopmentWebOrigin = 'http://127.0.0.1:5000';

  factory AppConfig.fromEnvironment() {
    const envName = String.fromEnvironment(
      'SEYRA_ENV',
      defaultValue: 'development',
    );
    const baseUrl = String.fromEnvironment(
      'SEYRA_API_BASE_URL',
      defaultValue: defaultDevelopmentBaseUrl,
    );
    const authMode = String.fromEnvironment(
      'SEYRA_AUTH_MODE',
      defaultValue: 'http',
    );

    return AppConfig(
      environment: _parseEnvironment(envName),
      apiBaseUrl: baseUrl,
      authBackendMode: authMode == 'mock'
          ? AuthBackendMode.mock
          : AuthBackendMode.http,
    );
  }

  static AppEnvironment _parseEnvironment(String name) {
    return AppEnvironment.values.firstWhere(
      (value) => value.name == name,
      orElse: () => AppEnvironment.development,
    );
  }

  /// Staging and production must use HTTPS. Development may use HTTP for the local Go server.
  void validate() {
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null || uri.host.isEmpty || !uri.hasScheme) {
      throw StateError('Invalid API base URL.');
    }

    if (environment != AppEnvironment.development && uri.scheme != 'https') {
      throw StateError(
        'TLS is required for the ${environment.name} environment.',
      );
    }
  }
}
