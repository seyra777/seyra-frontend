import 'package:flutter/material.dart';
import 'package:seyra/core/theme/app_colors.dart';

const _pillRadius = 999.0;

class AuthGradientButton extends StatelessWidget {
  const AuthGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(_pillRadius),
        child: Ink(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_pillRadius),
            gradient: enabled
                ? AppColors.brandGradientOf(context)
                : const LinearGradient(
                    colors: [Color(0xFFB8D4F5), Color(0xFF9BB6E8)],
                  ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.isDark(context)
                          ? AppColors.darkIndigo.withValues(alpha: 0.35)
                          : const Color(0x332F62F0),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: busy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 22),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class AuthOutlinedPillButton extends StatelessWidget {
  const AuthOutlinedPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark(context);
    final border = dark ? AppColors.darkCyan : AppColors.royal;
    final fg = dark ? Colors.white : AppColors.royal;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        foregroundColor: fg,
        backgroundColor: dark ? Colors.transparent : Colors.white,
        side: BorderSide(color: border, width: 1.4),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 22, color: fg),
            const SizedBox(width: 8),
          ],
          Text(label),
        ],
      ),
    );
  }
}
