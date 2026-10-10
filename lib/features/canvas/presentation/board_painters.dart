import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../domain/board.dart';

/// Where [toward] leaves [rect], on the line from the rect's center.
Offset _edgePoint(Rect rect, Offset toward) {
  final c = rect.center;
  final d = toward - c;
  if (d == Offset.zero) return c;
  final tx = d.dx == 0 ? double.infinity : rect.width / 2 / d.dx.abs();
  final ty = d.dy == 0 ? double.infinity : rect.height / 2 / d.dy.abs();
  return c + d * math.min(tx, ty);
}

/// Start and end of the arrow for [link], from card edge to card edge, or
/// null when a card is missing or the cards overlap.
(Offset, Offset)? linkSegment(Board board, BoardLink link) {
  final from = board.card(link.from)?.rect.inflate(6);
  final to = board.card(link.to)?.rect.inflate(6);
  if (from == null || to == null || from.overlaps(to)) return null;
  return (_edgePoint(from, to.center), _edgePoint(to, from.center));
}

/// Shortest distance from [p] to the segment [a]–[b].
double distanceToSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final lengthSquared = ab.distanceSquared;
  if (lengthSquared == 0) return (p - a).distance;
  final ap = p - a;
  final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / lengthSquared).clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

/// Whether [p] is within [radius] of [stroke]'s line.
bool strokeHitsPoint(BoardStroke stroke, Offset p, double radius) {
  final reach = radius + stroke.width / 2;
  if (!stroke.bounds.inflate(radius).contains(p)) return false;
  if (stroke.points.length == 1) {
    return (stroke.points.first - p).distance <= reach;
  }
  for (var i = 1; i < stroke.points.length; i++) {
    if (distanceToSegment(p, stroke.points[i - 1], stroke.points[i]) <= reach) {
      return true;
    }
  }
  return false;
}

/// A smooth path through [points], using midpoints as curve anchors.
Path _smoothPath(List<Offset> points) {
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  if (points.length == 2) return path..lineTo(points[1].dx, points[1].dy);
  for (var i = 1; i < points.length - 1; i++) {
    final mid = Offset.lerp(points[i], points[i + 1], 0.5)!;
    path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
  }
  return path..lineTo(points.last.dx, points.last.dy);
}

void _paintStroke(
  Canvas canvas,
  List<Offset> points,
  Color color,
  double width,
) {
  final paint = Paint()
    ..color = color
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  if (points.length == 1) {
    canvas.drawCircle(points.first, width / 2, paint);
    return;
  }
  canvas.drawPath(_smoothPath(points), paint..style = PaintingStyle.stroke);
}

void _paintArrow(Canvas canvas, Offset from, Offset to, Paint paint) {
  canvas.drawLine(from, to, paint);
  final angle = (to - from).direction;
  const head = 14.0, spread = 0.45;
  for (final side in [-spread, spread]) {
    canvas.drawLine(to, to - Offset.fromDirection(angle + side, head), paint);
  }
}

/// Faint dots every [spacing], like dot-grid paper.
class DotGridPainter extends CustomPainter {
  const DotGridPainter({required this.color, this.spacing = 32});

  final Color color;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final dots = <Offset>[
      for (var x = spacing; x < size.width; x += spacing)
        for (var y = spacing; y < size.height; y += spacing) Offset(x, y),
    ];
    canvas.drawPoints(
      PointMode.points,
      dots,
      Paint()
        ..color = color
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(DotGridPainter old) =>
      old.color != color || old.spacing != spacing;
}

/// Arrows between cards. The selected arrow is drawn thicker in [accent].
class LinksPainter extends CustomPainter {
  const LinksPainter({
    required this.board,
    required this.color,
    required this.accent,
    this.selectedId,
  });

  final Board board;
  final Color color;
  final Color accent;
  final String? selectedId;

  @override
  void paint(Canvas canvas, Size size) {
    for (final link in board.links) {
      final segment = linkSegment(board, link);
      if (segment == null) continue;
      final selected = link.id == selectedId;
      _paintArrow(
        canvas,
        segment.$1,
        segment.$2,
        Paint()
          ..color = selected ? accent : color
          ..strokeWidth = selected ? 3.4 : 2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(LinksPainter old) =>
      old.board != board ||
      old.color != color ||
      old.accent != accent ||
      old.selectedId != selectedId;
}

/// The color to paint a stroke saved as [argb]. Ink is stored as
/// [AppColors.ink] and drawn in the theme's [ink], so it stays visible on
/// the night desk.
Color strokeColor(int argb, Color ink) =>
    argb == AppColors.ink.toARGB32() ? ink : Color(argb);

/// Pen strokes, plus the stroke being drawn right now.
class StrokesPainter extends CustomPainter {
  const StrokesPainter({
    required this.strokes,
    required this.ink,
    this.current,
    this.currentColor = AppColors.ink,
    this.currentWidth = 3,
  });

  final List<BoardStroke> strokes;
  final Color ink;
  final List<Offset>? current;
  final Color currentColor;
  final double currentWidth;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      _paintStroke(canvas, s.points, strokeColor(s.color, ink), s.width);
    }
    final live = current;
    if (live != null && live.isNotEmpty) {
      _paintStroke(
        canvas,
        live,
        strokeColor(currentColor.toARGB32(), ink),
        currentWidth,
      );
    }
  }

  @override
  bool shouldRepaint(StrokesPainter old) =>
      old.strokes != strokes ||
      old.ink != ink ||
      old.current != current ||
      // The live stroke list grows in place while drawing.
      current != null;
}

/// A scaled-down sketch of a whole board, for the canvas list.
class BoardThumbnailPainter extends CustomPainter {
  const BoardThumbnailPainter({required this.board, required this.ink});

  final Board board;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = board.contentBounds;
    if (bounds == null) return;
    const pad = 12.0;
    final scale = math.min(
      1.0,
      math.min(
        (size.width - pad * 2) / bounds.width,
        (size.height - pad * 2) / bounds.height,
      ),
    );
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(scale)
      ..translate(-bounds.center.dx, -bounds.center.dy);

    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 / scale
      ..strokeCap = StrokeCap.round;
    for (final link in board.links) {
      final segment = linkSegment(board, link);
      if (segment != null) _paintArrow(canvas, segment.$1, segment.$2, line);
    }
    for (final card in board.cards) {
      final shape = RRect.fromRectAndRadius(
        card.rect,
        const Radius.circular(14),
      );
      canvas
        ..drawRRect(
          shape,
          Paint()..color = AppColors.notes[card.color % AppColors.notes.length],
        )
        ..drawRRect(shape, line);
    }
    for (final s in board.strokes) {
      _paintStroke(
        canvas,
        s.points,
        strokeColor(s.color, ink),
        math.max(s.width, 1 / scale),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BoardThumbnailPainter old) =>
      old.board != board || old.ink != ink;
}
