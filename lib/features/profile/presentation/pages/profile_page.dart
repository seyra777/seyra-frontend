import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/core/theme/app_colors.dart';
import 'package:seyra/features/auth/domain/entities/user.dart';
import 'package:seyra/features/branding/presentation/widgets/seyra_brand_mark.dart';
import 'package:seyra/features/profile/domain/entities/account.dart';
import 'package:seyra/features/profile/domain/entities/user_profile.dart';
import 'package:seyra/features/profile/domain/usecases/get_account_use_case.dart';
import 'package:seyra/features/profile/domain/usecases/watch_preferences_use_case.dart';
import 'package:seyra/features/profile/domain/usecases/watch_profile_use_case.dart';
import 'package:seyra/features/profile/presentation/widgets/profile_identity_card.dart';
import 'package:seyra/features/profile/presentation/widgets/settings_section.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.user,
    required this.watchProfile,
    required this.watchPreferences,
    required this.getAccount,
    required this.onOpenSettings,
    required this.onEditProfile,
    required this.onLogout,
  });

  final User user;
  final WatchProfileUseCase watchProfile;
  final WatchPreferencesUseCase watchPreferences;
  final GetAccountUseCase getAccount;
  final VoidCallback onOpenSettings;
  final VoidCallback onEditProfile;
  final Future<void> Function() onLogout;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final Stream<UserProfile> _profile;
  late final Stream<UserPreferences> _preferences;
  late Future<Result<Account>> _account;

  @override
  void initState() {
    super.initState();
    _profile = widget.watchProfile(
      userId: widget.user.id,
      username: widget.user.username,
    );
    _preferences = widget.watchPreferences();
    _account = widget.getAccount();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile>(
      stream: _profile,
      builder: (context, profileSnapshot) {
        return StreamBuilder<UserPreferences>(
          stream: _preferences,
          builder: (context, preferencesSnapshot) {
            final profile = profileSnapshot.data;
            final preferences = preferencesSnapshot.data;
            if (profile == null || preferences == null) {
              return const Center(child: CircularProgressIndicator());
            }

            return ColoredBox(
              color: AppColors.scaffoldOf(context),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: const SeyraBrandMark(height: 56),
                  ),
                  ProfileIdentityCard(
                    profile: profile,
                    onEdit: widget.onEditProfile,
                  ),
                  FutureBuilder<Result<Account>>(
                    future: _account,
                    builder: (context, snapshot) {
                      final result = snapshot.data;
                      final account = switch (result) {
                        Success(:final value) => value,
                        _ => null,
                      };
                      final failed = result is FailureResult<Account>;
                      return SettingsSection(
                        title: 'Account information',
                        children: [
                          SettingsTile(
                            icon: Icons.alternate_email,
                            title: 'Username',
                            subtitle:
                                '@${account?.username ?? widget.user.username}',
                          ),
                          SettingsTile(
                            icon: Icons.calendar_month_outlined,
                            title: 'Member since',
                            subtitle: snapshot.connectionState !=
                                    ConnectionState.done
                                ? 'Loading…'
                                : account == null
                                ? (failed
                                    ? 'Could not load from server'
                                    : 'Unavailable')
                                : _formatDate(account.createdAt),
                          ),
                          SettingsTile(
                            icon: Icons.fingerprint,
                            title: 'User ID',
                            subtitle: account?.id ?? profile.userId,
                            trailing: Icon(
                              Icons.copy_outlined,
                              size: 18,
                              color: AppColors.hintOf(context),
                            ),
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(
                                  text: account?.id ?? profile.userId,
                                ),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('User ID copied locally'),
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  SettingsSection(
                    title: 'About',
                    children: [
                      SettingsTile(
                        icon: Icons.notes_outlined,
                        title: 'Bio',
                        subtitle: profile.bio.isEmpty ? 'Add a bio' : profile.bio,
                        onTap: widget.onEditProfile,
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: 'Account',
                    children: [
                      SettingsTile(
                        key: const Key('profile_open_settings_tile'),
                        icon: Icons.settings_outlined,
                        title: 'Settings',
                        subtitle: 'Account, privacy, and more',
                        onTap: widget.onOpenSettings,
                      ),
                      SettingsTile(
                        key: const Key('profile_logout_tile'),
                        icon: Icons.logout,
                        iconColor: AppColors.dangerOf(context),
                        titleColor: AppColors.dangerOf(context),
                        title: 'Log out',
                        subtitle: 'Sign out of this device',
                        onTap: widget.onLogout,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final local = value.toLocal();
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }
}
