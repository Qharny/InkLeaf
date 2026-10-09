import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Hand-drawn decorations: double pencil outlines, marker highlights, wavy
/// separators and subtle ruled paper.
abstract final class SketchStyles {
  static const strokeWidth = 1.6;
  static const radius = 14.0;
  static const radiusSmall = 8.0;
  static const ruleSpacing = 28.0;
}

/// A rounded rectangle border whose edges wobble slightly, like a pen outline.
///
/// With [passes] > 1 the outline is traced again, thinner and slightly off,
/// like a pencil going over a line twice. The wobble is deterministic per
/// [seed], so a card keeps the same shape across rebuilds.
class SketchBorder extends OutlinedBorder {
  const SketchBorder({
    super.side = const BorderSide(
      color: AppColors.ink,
      width: SketchStyles.strokeWidth,
    ),
    this.radius = SketchStyles.radius,
    this.wobble = 1.4,
    this.seed = 7,
    this.passes = 2,
  });

  final double radius;
  final double wobble;
  final int seed;
  final int passes;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  Path _path(Rect rect, [int pass = 0]) {
    final rng = math.Random(seed + pass * 31);
    double j() => (rng.nextDouble() - 0.5) * 2 * wobble;
    final r = math.min(radius, rect.shortestSide / 2);
    final l = rect.left, t = rect.top, rt = rect.right, b = rect.bottom;

    return Path()
      ..moveTo(l + r, t)
      ..quadraticBezierTo(rect.center.dx + j(), t + j(), rt - r + j(), t + j())
      ..quadraticBezierTo(rt + j(), t + j(), rt + j(), t + r + j())
      ..quadraticBezierTo(rt + j(), rect.center.dy + j(), rt + j(), b - r + j())
      ..quadraticBezierTo(rt + j(), b + j(), rt - r + j(), b + j())
      ..quadraticBezierTo(rect.center.dx + j(), b + j(), l + r + j(), b + j())
      ..quadraticBezierTo(l + j(), b + j(), l + j(), b - r + j())
      ..quadraticBezierTo(l + j(), rect.center.dy + j(), l + j(), t + r + j())
      ..quadraticBezierTo(l + j(), t + j(), l + r, t)
      ..close();
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _path(rect.deflate(side.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    final paint = Paint()
      ..color = side.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = side.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(_path(rect.deflate(side.width / 2)), paint);
    for (var pass = 1; pass < passes; pass++) {
      canvas.drawPath(
        _path(rect.deflate(side.width / 2), pass),
        paint
          ..color = side.color.withValues(alpha: side.color.a * 0.55)
          ..strokeWidth = side.width * 0.6,
      );
    }
  }

  @override
  ShapeBorder scale(double t) => SketchBorder(
    side: side.scale(t),
    radius: radius * t,
    wobble: wobble * t,
    seed: seed,
    passes: passes,
  );

  @override
  SketchBorder copyWith({BorderSide? side, double? radius, int? seed}) =>
      SketchBorder(
        side: side ?? this.side,
        radius: radius ?? this.radius,
        wobble: wobble,
        seed: seed ?? this.seed,
        passes: passes,
      );

  @override
  bool operator ==(Object other) =>
      other is SketchBorder &&
      other.side == side &&
      other.radius == radius &&
      other.wobble == wobble &&
      other.seed == seed &&
      other.passes == passes;

  @override
  int get hashCode => Object.hash(side, radius, wobble, seed, passes);
}

/// Faint horizontal rules with an optional margin line, for notebook pages.
class RuledPaperPainter extends CustomPainter {
  const RuledPaperPainter({
    this.lineColor = AppColors.ruledLine,
    this.marginColor = AppColors.margin,
    this.spacing = SketchStyles.ruleSpacing,
    this.marginX = 40,
    this.showMargin = true,
  });

  final Color lineColor;
  final Color marginColor;
  final double spacing;
  final double marginX;
  final bool showMargin;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = lineColor.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (var y = spacing * 2; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    if (showMargin) {
      canvas.drawLine(
        Offset(marginX, 0),
        Offset(marginX, size.height),
        Paint()
          ..color = marginColor.withValues(alpha: 0.7)
          ..strokeWidth = 1.2,
      );
    }
  }

  @override
  bool shouldRepaint(RuledPaperPainter old) =>
      old.lineColor != lineColor ||
      old.marginColor != marginColor ||
      old.spacing != spacing ||
      old.marginX != marginX ||
      old.showMargin != showMargin;
}

/// A translucent marker swipe behind [child], like highlighting a heading.
class MarkerHighlight extends StatelessWidget {
  const MarkerHighlight({
    super.key,
    required this.child,
    this.color = AppColors.markerYellow,
    this.seed = 5,
  });

  final Widget child;
  final Color color;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MarkerPainter(color, seed),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: child,
      ),
    );
  }
}

class _MarkerPainter extends CustomPainter {
  const _MarkerPainter(this.color, this.seed);

  final Color color;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    double j(double amount) => (rng.nextDouble() - 0.5) * 2 * amount;
    // Covers the lower ~70% of the text, with a slight tilt and ragged ends.
    final top = size.height * 0.28;
    final path = Path()
      ..moveTo(j(2), top + j(2))
      ..quadraticBezierTo(
        size.width / 2,
        top + j(3),
        size.width + j(3),
        top + j(2),
      )
      ..lineTo(size.width + j(4), size.height - 2 + j(2))
      ..quadraticBezierTo(
        size.width / 2,
        size.height + j(3),
        j(3),
        size.height - 1 + j(2),
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_MarkerPainter old) =>
      old.color != color || old.seed != seed;
}

/// A loose hand-drawn horizontal line, used instead of a ruler-straight
/// [Divider] between sections.
class SketchDivider extends StatelessWidget {
  const SketchDivider({
    super.key,
    this.color,
    this.height = 24,
    this.thickness = 1.4,
    this.seed = 9,
  });

  final Color? color;
  final double height;
  final double thickness;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SketchLinePainter(
          color ?? Theme.of(context).colorScheme.onSurfaceVariant,
          thickness,
          seed,
        ),
      ),
    );
  }
}

class _SketchLinePainter extends CustomPainter {
  const _SketchLinePainter(this.color, this.thickness, this.seed);

  final Color color;
  final double thickness;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    final y = size.height / 2;
    final path = Path()..moveTo(0, y);
    const step = 40.0;
    for (var x = step; x < size.width + step; x += step) {
      path.quadraticBezierTo(
        x - step / 2,
        y + (rng.nextDouble() - 0.5) * 2.4,
        math.min(x, size.width),
        y + (rng.nextDouble() - 0.5) * 1.2,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SketchLinePainter old) =>
      old.color != color || old.thickness != thickness || old.seed != seed;
}
