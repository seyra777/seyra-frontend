import 'package:flutter/widgets.dart';
import 'package:seyra/app/app.dart';
import 'package:seyra/app/di/app_dependencies.dart';

/// Starts the application. Keep side-effectful setup here, not in [main].
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDependencies.initialize();
  runApp(const SeyraApp());
}
