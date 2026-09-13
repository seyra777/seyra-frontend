import 'package:flutter_test/flutter_test.dart';
import 'package:seyra/core/config/app_config.dart';

void main() {
  test('accepts development HTTP for the local Go server', () {
    const config = AppConfig(
      environment: AppEnvironment.development,
      apiBaseUrl: AppConfig.defaultDevelopmentBaseUrl,
    );

    expect(config.validate, returnsNormally);
    expect(config.apiBaseUrl.startsWith('http://'), isTrue);
  });

  test('rejects non-TLS URLs in staging', () {
    const config = AppConfig(
      environment: AppEnvironment.staging,
      apiBaseUrl: 'http://example.invalid',
    );

    expect(config.validate, throwsStateError);
  });

  test('rejects non-TLS URLs in production', () {
    const config = AppConfig(
      environment: AppEnvironment.production,
      apiBaseUrl: 'http://example.invalid',
    );

    expect(config.validate, throwsStateError);
  });

  test('accepts HTTPS in production', () {
    const config = AppConfig(
      environment: AppEnvironment.production,
      apiBaseUrl: 'https://api.example.invalid',
    );

    expect(config.validate, returnsNormally);
  });
}
