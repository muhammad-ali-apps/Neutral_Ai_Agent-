import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Renders an animated neon red laser border, exactly matching the sidebar selected feature indicator.
class MovingRedBorderPainter extends CustomPainter {
  final double progress;
  final double borderRadius;
  final bool isDark;

  const MovingRedBorderPainter({
    required this.progress,
    required this.borderRadius,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(1.0),
      Radius.circular(borderRadius),
    );

    // 1. Static subtle red guide outline
    final trackPaint = Paint()
      ..color = const Color(0xFFEF4444).withValues(alpha: isDark ? 0.22 : 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(rrect, trackPaint);

    // 2. Rotating sweep gradient red beam
    final sweepGradient = SweepGradient(
      center: Alignment.center,
      transform: GradientRotation(progress * 2 * math.pi),
      colors: const [
        Colors.transparent,
        Color(0x00EF4444),
        Color(0x44EF4444),
        Color(0xFFEF4444),
        Color(0xFFFF6666),
        Color(0xFFEF4444),
        Color(0x00EF4444),
        Colors.transparent,
      ],
      stops: const [0.0, 0.65, 0.78, 0.88, 0.94, 0.98, 1.0, 1.0],
    );

    final shader = sweepGradient.createShader(rect);

    // 3. Glowing neon beam halo
    final glowPaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawRRect(rrect, glowPaint);

    // 4. Sharp high-intensity laser line
    final beamPaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(rrect, beamPaint);
  }

  @override
  bool shouldRepaint(MovingRedBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.isDark != isDark;
  }
}
