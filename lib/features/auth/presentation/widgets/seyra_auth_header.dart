import 'package:flutter/material.dart';
import 'package:seyra/core/theme/app_colors.dart';
import 'package:seyra/features/branding/presentation/widgets/seyra_brand_mark.dart';

class SeyraAuthHeader extends StatelessWidget {
  const SeyraAuthHeader({
    super.key,
    this.subtitle = 'Private conversations. A safer tomorrow.',
    this.detail =
        'End-to-end encrypted messaging, calls and channels.',
    this.compact = false,
  });

  final String subtitle;
  final String? detail;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        SeyraBrandMark(height: compact ? 72 : 96),
        SizedBox(height: compact ? 24 : 32),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: AppColors.textOf(context),
            fontWeight: compact ? FontWeight.w600 : FontWeight.w800,
            fontSize: compact ? 22 : 26,
            height: 1.25,
            letterSpacing: -0.4,
          ),
        ),
        if (detail != null && detail!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            detail!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.hintOf(context),
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}
