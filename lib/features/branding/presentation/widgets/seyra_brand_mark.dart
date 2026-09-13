import 'package:flutter/material.dart';
import 'package:seyra/core/constants/app_constants.dart';
import 'package:seyra/core/theme/app_colors.dart';

/// Exact Seyra lockup from branding assets (icon + wordmark).
/// Light uses Logo-Version-1; dark uses Logo-Version-2.
///
/// [height] is always painted at that size. Parents cannot shrink it.
class SeyraBrandMark extends StatelessWidget {
  const SeyraBrandMark({
    super.key,
    this.height = 48,
    this.alignment = Alignment.center,
  });

  final double height;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark(context);
    return Align(
      alignment: alignment,
      child: UnconstrainedBox(
        alignment: alignment,
        clipBehavior: Clip.none,
        child: Image.asset(
          dark ? AppAssets.seyraLogoDark : AppAssets.seyraLogoLight,
          height: height,
          fit: BoxFit.fitHeight,
          filterQuality: FilterQuality.high,
          semanticLabel: AppConstants.appName,
        ),
      ),
    );
  }
}

/// Circular app icon only (Icon_Design_1).
class SeyraAppIcon extends StatelessWidget {
  const SeyraAppIcon({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppAssets.seyraIcon,
      width: size,
      height: size,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      semanticLabel: AppConstants.appName,
    );
  }
}
