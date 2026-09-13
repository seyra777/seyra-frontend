import 'package:flutter/material.dart';
import 'package:seyra/app/di/app_dependencies.dart';
import 'package:seyra/app/router/app_navigator.dart';
import 'package:seyra/app/router/app_router.dart';
import 'package:seyra/app/router/app_routes.dart';
import 'package:seyra/core/constants/app_constants.dart';
import 'package:seyra/core/theme/app_theme.dart';

class SeyraApp extends StatelessWidget {
  const SeyraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppDependencies.themeController,
      builder: (context, mode, _) {
        return MaterialApp(
          title: AppConstants.appName,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          navigatorKey: AppNavigator.key,
          initialRoute: AppRoutes.home,
          onGenerateRoute: AppRouter.onGenerateRoute,
        );
      },
    );
  }
}
