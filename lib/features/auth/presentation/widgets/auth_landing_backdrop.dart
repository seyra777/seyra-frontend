import 'package:flutter/material.dart';
import 'package:seyra/core/theme/app_colors.dart';

/// Soft corner blobs and bokeh used on auth screens.
class AuthLandingBackdrop extends StatelessWidget {
  const AuthLandingBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: AuthLandingBackdropPainter(dark: AppColors.isDark(context)),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class AuthLandingBackdropPainter extends CustomPainter {
  const AuthLandingBackdropPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (dark) {
      _paintBlob(
        canvas,
        rect: Rect.fromLTWH(
          size.width * 0.35,
          -size.height * 0.18,
          size.width * 0.9,
          size.height * 0.42,
        ),
        colors: [
          AppColors.darkBlobCyan.withValues(alpha: 0.35),
          AppColors.darkBlobDeep.withValues(alpha: 0.22),
        ],
      );
      _paintBlob(
        canvas,
        rect: Rect.fromLTWH(
          -size.width * 0.35,
          size.height * 0.62,
          size.width * 0.95,
          size.height * 0.48,
        ),
        colors: [
          AppColors.darkBlobDeep.withValues(alpha: 0.40),
          AppColors.darkBlobCyan.withValues(alpha: 0.22),
        ],
      );
      final glow = Paint()
        ..color = AppColors.darkBlobCyan.withValues(alpha: 0.20);
      canvas.drawCircle(
        Offset(size.width * 0.88, size.height * 0.22),
        size.width * 0.28,
        glow,
      );
      canvas.drawCircle(
        Offset(size.width * 0.08, size.height * 0.82),
        size.width * 0.32,
        glow,
      );
      return;
    }

    _paintBlob(
      canvas,
      rect: Rect.fromLTWH(
        -size.width * 0.28,
        -size.height * 0.16,
        size.width * 0.92,
        size.height * 0.38,
      ),
      colors: const [AppColors.blobCyan, AppColors.blobBlue],
    );
    _paintBlob(
      canvas,
      rect: Rect.fromLTWH(
        -size.width * 0.18,
        -size.height * 0.02,
        size.width * 0.62,
        size.height * 0.22,
      ),
      colors: const [Color(0xAA9BE8FF), Color(0xCC4F86F5)],
    );

    _paintBlob(
      canvas,
      rect: Rect.fromLTWH(
        size.width * 0.42,
        size.height * 0.72,
        size.width * 0.78,
        size.height * 0.38,
      ),
      colors: const [AppColors.blobBlue, AppColors.royal],
    );
    _paintBlob(
      canvas,
      rect: Rect.fromLTWH(
        size.width * 0.58,
        size.height * 0.78,
        size.width * 0.62,
        size.height * 0.28,
      ),
      colors: const [Color(0xCC5BA0FF), Color(0xFF2454D6)],
    );

    final bokeh = Paint()..color = const Color(0x3348B7FF);
    canvas.drawCircle(
      Offset(size.width * 0.86, size.height * 0.30),
      size.width * 0.16,
      bokeh,
    );
    canvas.drawCircle(
      Offset(size.width * 0.12, size.height * 0.78),
      size.width * 0.14,
      bokeh,
    );
  }

  void _paintBlob(
    Canvas canvas, {
    required Rect rect,
    required List<Color> colors,
  }) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ).createShader(rect);
    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(covariant AuthLandingBackdropPainter oldDelegate) {
    return oldDelegate.dark != dark;
  }
}
