import 'dart:async';

import 'package:flutter/material.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/core/theme/app_colors.dart';
import 'package:seyra/features/auth/domain/entities/user.dart';
import 'package:seyra/features/notifications/data/local_notification_display.dart';
import 'package:seyra/features/notifications/data/push_coordinator.dart';
import 'package:seyra/features/notifications/domain/entities/notification_models.dart';
import 'package:seyra/features/notifications/domain/usecases/notification_use_cases.dart';
import 'package:seyra/features/profile/domain/entities/user_profile.dart';
import 'package:seyra/features/profile/domain/usecases/update_preferences_use_case.dart';
import 'package:seyra/features/profile/domain/usecases/watch_preferences_use_case.dart';
import 'package:seyra/features/profile/domain/usecases/watch_profile_use_case.dart';
import 'package:seyra/features/profile/presentation/widgets/profile_identity_card.dart';
import 'package:seyra/features/profile/presentation/widgets/settings_section.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.user,
    required this.watchProfile,
    required this.watchPreferences,
    required this.updatePreferences,
    required this.getNotificationPreferences,
    required this.updateNotificationPreferences,
    required this.pushCoordinator,
    required this.onEditProfile,
    required this.onUsername,
    required this.onLogout,
    required this.onDeleteAccount,
    this.onPrivacy,
    this.onSessions,
    this.onBots,
    this.onCalls,
    this.onEncryption,
    this.onSecurity,
    this.onAbout,
    this.onStorage,
  });

  final User user;
  final WatchProfileUseCase watchProfile;
  final WatchPreferencesUseCase watchPreferences;
  final UpdatePreferencesUseCase updatePreferences;
  final GetNotificationPreferencesUseCase getNotificationPreferences;
  final UpdateNotificationPreferencesUseCase updateNotificationPreferences;
  final PushCoordinator pushCoordinator;
  final VoidCallback onEditProfile;
  final ValueChanged<String> onUsername;
  final Future<void> Function() onLogout;
  final VoidCallback onDeleteAccount;
  final VoidCallback? onPrivacy;
  final VoidCallback? onSessions;
  final VoidCallback? onBots;
  final VoidCallback? onCalls;
  final VoidCallback? onEncryption;
  final VoidCallback? onSecurity;
  final VoidCallback? onAbout;
  final VoidCallback? onStorage;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final Stream<UserPreferences> _preferences;
  late final Stream<UserProfile> _profile;
  NotificationPreferences _alerts = const NotificationPreferences();
  var _deviceRegistered = false;

  @override
  void initState() {
    super.initState();
    _preferences = widget.watchPreferences();
    _profile = widget.watchProfile(
      userId: widget.user.id,
      username: widget.user.username,
    );
    unawaited(_loadAlerts());
    unawaited(_loadDevice());
  }

  Future<void> _loadDevice() async {
    final registered = await widget.pushCoordinator.hasServerDevice();
    if (mounted) {
      setState(() => _deviceRegistered = registered);
    }
  }

  Future<void> _loadAlerts() async {
    final result = await widget.getNotificationPreferences();
    if (!mounted) {
      return;
    }
    if (result is Success<NotificationPreferences>) {
      setState(() => _alerts = result.value);
    }
  }

  Future<void> _saveAlerts(NotificationPreferences next) async {
    setState(() => _alerts = next);
    await widget.updateNotificationPreferences(next);
  }

  void _applySound(bool enabled) {
    final display = widget.pushCoordinator.display;
    if (display is LocalNotificationDisplay) {
      display.playSound = enabled;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: StreamBuilder<UserProfile>(
        stream: _profile,
        builder: (context, profileSnap) {
          final username =
              profileSnap.data?.username ?? widget.user.username;
          return StreamBuilder<UserPreferences>(
            stream: _preferences,
            builder: (context, snapshot) {
              final preferences = snapshot.data;
              if (preferences == null) {
                return const Center(child: CircularProgressIndicator());
              }

              return ListView(
                key: const Key('settings_scroll'),
                padding: const EdgeInsets.only(bottom: 40),
                children: [
                  SettingsSection(
                    title: 'Account',
                    children: [
                      SettingsTile(
                        key: const Key('settings_edit_profile_tile'),
                        icon: Icons.person_outline,
                        title: 'Edit profile',
                        subtitle: 'Display name, bio, and photo — saved on the server',
                        onTap: widget.onEditProfile,
                      ),
                      SettingsTile(
                        icon: Icons.alternate_email,
                        title: 'Username',
                        subtitle: '@$username',
                        onTap: () => widget.onUsername(username),
                      ),
                      SettingsTile(
                        icon: Icons.manage_accounts_outlined,
                        title: 'Devices & sessions',
                        subtitle: 'This device and other signed-in sessions',
                        onTap: widget.onSessions,
                      ),
                      SettingsTile(
                        key: const Key('settings_delete_account_tile'),
                        icon: Icons.delete_outline,
                        iconColor: AppColors.dangerOf(context),
                        titleColor: AppColors.dangerOf(context),
                        title: 'Delete account',
                        subtitle: 'Permanently delete your Seyra account',
                        onTap: widget.onDeleteAccount,
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: 'Privacy & Security',
                    children: [
                      SettingsTile(
                        icon: Icons.lock_outline,
                        title: 'Privacy controls',
                        subtitle: 'Presence, receipts, profile, photo, previews',
                        onTap: widget.onPrivacy,
                      ),
                      SettingsTile(
                        icon: Icons.schedule,
                        title: 'Last seen',
                        subtitle: visibilityLabel(preferences.lastSeenVisibility),
                        onTap: () => _pickVisibility(
                          context,
                          title: 'Last seen',
                          current: preferences.lastSeenVisibility,
                          onSelected: (value) {
                            widget.updatePreferences(
                              preferences.copyWith(lastSeenVisibility: value),
                            );
                          },
                        ),
                      ),
                      SettingsTile(
                        icon: Icons.photo_outlined,
                        title: 'Profile photo',
                        subtitle: visibilityLabel(
                          preferences.profilePhotoVisibility,
                        ),
                        onTap: () => _pickVisibility(
                          context,
                          title: 'Profile photo',
                          current: preferences.profilePhotoVisibility,
                          onSelected: (value) {
                            widget.updatePreferences(
                              preferences.copyWith(profilePhotoVisibility: value),
                            );
                          },
                        ),
                      ),
                      SettingsTile(
                        icon: Icons.smart_toy_outlined,
                        title: 'Bots',
                        subtitle: 'Create bots and grant room permissions',
                        onTap: widget.onBots,
                      ),
                      SettingsTile(
                        icon: Icons.call_outlined,
                        title: 'Call history',
                        onTap: widget.onCalls,
                      ),
                      SettingsTile(
                        icon: Icons.lock_outline,
                        title: 'Encryption',
                        subtitle:
                            'Signal Protocol for new 1:1 messages when keys exist. Older messages stay plaintext.',
                        onTap: widget.onEncryption,
                      ),
                      SettingsTile(
                        icon: Icons.security_outlined,
                        title: 'Security settings',
                        subtitle: 'Sessions, privacy, and the current security model',
                        onTap: widget.onSecurity,
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: 'Notifications',
                    children: [
                      SwitchListTile(
                        secondary: _iconWrap(Icons.notifications_outlined),
                        title: const Text('Message notifications'),
                        subtitle: const Text('Saved on the Seyra server'),
                        value: _alerts.messagesEnabled,
                        onChanged: (value) {
                          widget.updatePreferences(
                            preferences.copyWith(messageNotifications: value),
                          );
                          unawaited(
                            _saveAlerts(_alerts.copyWith(messagesEnabled: value)),
                          );
                        },
                      ),
                      SwitchListTile(
                        secondary: _iconWrap(Icons.visibility_outlined),
                        title: const Text('Message preview'),
                        subtitle: const Text('Off = generic “New message” text'),
                        value: _alerts.showPreview,
                        onChanged: (value) {
                          unawaited(
                            _saveAlerts(_alerts.copyWith(showPreview: value)),
                          );
                        },
                      ),
                      SwitchListTile(
                        secondary: _iconWrap(Icons.volume_up_outlined),
                        title: const Text('Sounds'),
                        subtitle: const Text('Local alert sound on this device'),
                        value: preferences.soundEnabled,
                        onChanged: (value) {
                          _applySound(value);
                          widget.updatePreferences(
                            preferences.copyWith(soundEnabled: value),
                          );
                        },
                      ),
                      SwitchListTile(
                        secondary: _iconWrap(Icons.call_outlined),
                        title: const Text('Call notifications'),
                        subtitle: const Text('Saved on the Seyra server'),
                        value: _alerts.callsEnabled,
                        onChanged: (value) {
                          widget.updatePreferences(
                            preferences.copyWith(callNotifications: value),
                          );
                          unawaited(
                            _saveAlerts(_alerts.copyWith(callsEnabled: value)),
                          );
                        },
                      ),
                      SettingsTile(
                        icon: Icons.smartphone_outlined,
                        title: 'This device',
                        subtitle: _deviceSubtitle(),
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: 'Appearance',
                    children: [
                      SwitchListTile(
                        secondary: _iconWrap(Icons.dark_mode_outlined),
                        title: const Text('Dark mode'),
                        subtitle: const Text('Off uses light mode'),
                        value: Theme.of(context).brightness == Brightness.dark,
                        onChanged: (value) {
                          unawaited(
                            widget.updatePreferences(
                              preferences.copyWith(
                                appearance: value
                                    ? AppearancePreference.dark
                                    : AppearancePreference.light,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: 'About Seyra',
                    children: [
                      SettingsTile(
                        icon: Icons.info_outline,
                        title: 'Seyra',
                        subtitle: 'Version 1.0.0',
                        onTap: widget.onAbout,
                      ),
                      SettingsTile(
                        icon: Icons.sd_storage_outlined,
                        title: 'Storage usage',
                        subtitle: 'Folder estimate vs OS app size',
                        onTap: widget.onStorage,
                      ),
                      SettingsTile(
                        icon: Icons.cleaning_services_outlined,
                        title: 'Clear cache',
                        subtitle: 'Temp and cache only — not keys or login',
                        onTap: widget.onStorage,
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: 'Danger zone',
                    children: [
                      SettingsTile(
                        key: const Key('settings_logout_tile'),
                        icon: Icons.logout,
                        iconColor: AppColors.dangerOf(context),
                        titleColor: AppColors.dangerOf(context),
                        title: 'Log out',
                        subtitle: 'Revoke this session and return to sign-in',
                        onTap: () => widget.onLogout(),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _deviceSubtitle() {
    final platform = widget.pushCoordinator.platformLabel;
    if (!widget.pushCoordinator.isStarted) {
      return '$platform · not registered in this session. Sign in to register. Closed-app delivery also needs SEYRA_PUSH_WEBHOOK_URL on the server.';
    }
    if (_deviceRegistered) {
      return '$platform · registered with Seyra for in-app and foreground alerts. Closed-app/FCM delivery needs SEYRA_PUSH_WEBHOOK_URL — this app does not claim that gateway is configured.';
    }
    return '$platform · coordinator started, server device id not stored yet. Closed-app delivery needs SEYRA_PUSH_WEBHOOK_URL.';
  }

  Widget _iconWrap(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.accentOf(context).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: AppColors.accentOf(context), size: 20),
    );
  }

  Future<void> _pickVisibility(
    BuildContext context, {
    required String title,
    required VisibilityPreference current,
    required ValueChanged<VisibilityPreference> onSelected,
  }) async {
    const options = [
      VisibilityPreference.everyone,
      VisibilityPreference.nobody,
    ];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(title, style: Theme.of(context).textTheme.titleMedium),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Only Everyone and Nobody are enforced. Seyra has no contacts graph for “My contacts”.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              for (final value in options)
                ListTile(
                  title: Text(visibilityLabel(value)),
                  trailing: value == current
                      ? Icon(Icons.check, color: AppColors.accentOf(context))
                      : null,
                  onTap: () {
                    onSelected(value);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
