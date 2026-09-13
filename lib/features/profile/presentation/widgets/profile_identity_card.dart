import 'package:flutter/material.dart';
import 'package:seyra/core/theme/app_colors.dart';
import 'package:seyra/features/profile/domain/entities/user_profile.dart';
import 'package:seyra/features/profile/presentation/widgets/user_avatar.dart';

String visibilityLabel(VisibilityPreference value) {
  return switch (value) {
    VisibilityPreference.everyone => 'Everyone',
    VisibilityPreference.contacts => 'My contacts',
    VisibilityPreference.nobody => 'Nobody',
  };
}

String appearanceLabel(AppearancePreference value) {
  return switch (value) {
    AppearancePreference.light => 'Light',
    AppearancePreference.dark => 'Dark',
  };
}

class ProfileIdentityCard extends StatelessWidget {
  const ProfileIdentityCard({
    super.key,
    required this.profile,
    required this.onEdit,
  });

  final UserProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final bio = profile.bio.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              UserAvatar(
                userId: profile.userId,
                initials: profile.displayName,
                radius: 56,
                hasAvatar: profile.hasAvatar,
              ),
              Material(
                color: AppColors.accentOf(context),
                shape: const CircleBorder(),
                child: InkWell(
                  key: const Key('edit_profile_button'),
                  customBorder: const CircleBorder(),
                  onTap: onEdit,
                  child: const SizedBox(
                    width: 34,
                    height: 34,
                    child: Icon(Icons.camera_alt, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            profile.displayName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '@${profile.username}',
            style: TextStyle(
              color: AppColors.accentOf(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.mutedOf(context),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                bio,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textOf(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          if (profile.isPremium) ...[
            const SizedBox(height: 10),
            const _PremiumBadge(),
          ],
        ],
      ),
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge();

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF3A2E14) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Premium',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: dark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
        ),
      ),
    );
  }
}
