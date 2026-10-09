import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Small hand-drawn decorations borrowed from the logo: spark rays, leaves
/// and squiggles. Purely decorative, so they are excluded from semantics.

Paint _ink(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// Three short strokes radiating out, like the "shine" marks on the logo.
class SparkRays extends StatelessWidget {
  const SparkRays({
    super.key,
    this.size = 40,
    this.angle = -math.pi * 3 / 4,
    this.color = AppColors.ink,
  });

  final double size;

  /// Direction the rays point, in radians (0 = right).
  final double angle;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _RaysPainter(angle, color),
    ),
  );
}

class _RaysPainter extends CustomPainter {
  const _RaysPainter(this.angle, this.color);

  final double angle;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final paint = _ink(color, w * 0.07);
    // Rays fan out from a point behind the widget (the "glowing" object), so
    // they stay separate strokes instead of meeting like an arrowhead.
    final dir = Offset(math.cos(angle), math.sin(angle));
    final focus = size.center(Offset.zero) - dir * (w * 0.6);
    for (final spread in [-0.42, 0.0, 0.42]) {
      final a = angle + spread;
      final ray = Offset(math.cos(a), math.sin(a));
      // The middle ray is the longest.
      final outer = w * (spread == 0 ? 1.05 : 0.95);
      canvas.drawLine(focus + ray * (w * 0.5), focus + ray * outer, paint);
    }
  }

  @override
  bool shouldRepaint(_RaysPainter old) =>
      old.angle != angle || old.color != color;
}

/// A sage leaf with an ink outline and midrib.
class LeafDoodle extends StatelessWidget {
  const LeafDoodle({
    super.key,
    this.size = 32,
    this.rotation = 0,
    this.outlined = true,
    this.color = AppColors.sage,
  });

  final double size;
  final double rotation;
  final bool outlined;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Transform.rotate(
      angle: rotation,
      child: CustomPaint(
        size: Size(size * 0.62, size),
        painter: _LeafPainter(color, outlined),
      ),
    ),
  );
}

class _LeafPainter extends CustomPainter {
  const _LeafPainter(this.color, this.outlined);

  final Color color;
  final bool outlined;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final leaf = Path()
      ..moveTo(w / 2, 0)
      ..quadraticBezierTo(w * 1.05, h * 0.45, w / 2, h * 0.92)
      ..quadraticBezierTo(-w * 0.05, h * 0.45, w / 2, 0)
      ..close();
    canvas.drawPath(leaf, Paint()..color = color);
    if (!outlined) return;
    final stroke = _ink(AppColors.ink, math.max(1.2, w * 0.07));
    canvas.drawPath(leaf, stroke);
    // Midrib running a little past the leaf as a stem.
    canvas.drawPath(
      Path()
        ..moveTo(w / 2, h * 0.18)
        ..quadraticBezierTo(w * 0.56, h * 0.6, w * 0.4, h),
      stroke,
    );
  }

  @override
  bool shouldRepaint(_LeafPainter old) =>
      old.color != color || old.outlined != outlined;
}

/// A loose wavy underline, like the green swoosh under the logo.
class SquiggleDoodle extends StatelessWidget {
  const SquiggleDoodle({
    super.key,
    this.width = 120,
    this.color = AppColors.sage,
    this.thickness = 3,
  });

  final double width;
  final Color color;
  final double thickness;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size(width, width * 0.18),
      painter: _SquigglePainter(color, thickness),
    ),
  );
}

class _SquigglePainter extends CustomPainter {
  const _SquigglePainter(this.color, this.thickness);

  final Color color;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.7)
        ..cubicTo(w * 0.2, h * 0.1, w * 0.35, h * 0.2, w * 0.5, h * 0.6)
        ..cubicTo(w * 0.62, h * 0.95, w * 0.8, h * 0.6, w, h * 0.3),
      _ink(color, thickness),
    );
  }

  @override
  bool shouldRepaint(_SquigglePainter old) =>
      old.color != color || old.thickness != thickness;
}
