import 'package:flutter/material.dart';
import 'package:seyra/features/profile/domain/entities/user_profile.dart';

final class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.light);

  void apply(AppearancePreference appearance) {
    value = appearance == AppearancePreference.dark
        ? ThemeMode.dark
        : ThemeMode.light;
  }
}
