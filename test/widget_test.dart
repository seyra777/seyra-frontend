import 'package:flutter_test/flutter_test.dart';
import 'package:seyra/app/app.dart';
import 'package:seyra/app/di/app_dependencies.dart';
import 'package:seyra/core/constants/app_constants.dart';
import 'package:seyra/features/auth/data/datasources/mock_auth_remote_data_source.dart';

void main() {
  testWidgets('Seyra application shell loads', (WidgetTester tester) async {
    await AppDependencies.initialize(
      remoteDataSource: MockAuthRemoteDataSource(),
    );
    await tester.pumpWidget(const SeyraApp());
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(AppConstants.appName), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
