import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Where [context]'s widget sits on screen, or null if it isn't laid out.
Rect? globalRectOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize || !box.attached) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// Plays a deleted note's exit over everything: the page folds in half,
/// crumples into a ball and is tossed in an arc into a bin that pops up
/// from the bottom, whose lid opens to catch it.
///
/// Call it before removing the note (it reads [context] straight away), then
/// remove the note right after; the animation runs on its own in the root
/// overlay and survives the page closing. Skipped with reduced motion on.
Future<void> throwInBin(
  BuildContext context, {
  required Rect from,
  required Color paper,
}) => _play(context, page: from, paper: paper, reverse: false);

/// The reverse, for Undo: the bin pops up, the ball flies out and unfolds
/// into [to], where the restored item now sits. Quicker than the throw.
Future<void> pullFromBin(
  BuildContext context, {
  required Rect to,
  required Color paper,
}) => _play(context, page: to, paper: paper, reverse: true);

/// Things that just came back out of the bin (via Undo), by id, so the
/// screen showing them can play [pullFromBin] into their spot. Whoever
/// plays it sets the value back to null.
abstract final class BinEvents {
  static final note = ValueNotifier<String?>(null);
  static final collection = ValueNotifier<String?>(null);

  /// Notifies even when the same id is restored twice in a row.
  static void restored(ValueNotifier<String?> kind, String id) {
    kind.value = null;
    kind.value = id;
  }
}

Future<void> _play(
  BuildContext context, {
  required Rect page,
  required Color paper,
  required bool reverse,
}) {
  if (MediaQuery.disableAnimationsOf(context)) return Future.value();
  final overlay = Overlay.of(context, rootOverlay: true);
  final scheme = Theme.of(context).colorScheme;
  final done = Completer<void>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _BinThrow(
      from: page,
      reverse: reverse,
      paper: paper,
      ink: scheme.outline,
      bin: scheme.surfaceContainerHighest,
      onDone: () {
        entry.remove();
        done.complete();
      },
    ),
  );
  overlay.insert(entry);
  return done.future;
}

class _BinThrow extends StatefulWidget {
  const _BinThrow({
    required this.from,
    required this.reverse,
    required this.paper,
    required this.ink,
    required this.bin,
    required this.onDone,
  });

  final Rect from;

  /// Plays backwards: out of the bin and into [from].
  final bool reverse;
  final Color paper;
  final Color ink;
  final Color bin;
  final VoidCallback onDone;

  @override
  State<_BinThrow> createState() => _BinThrowState();
}

class _BinThrowState extends State<_BinThrow>
    with SingleTickerProviderStateMixin {
  late final _t = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
    reverseDuration: const Duration(milliseconds: 650),
  );

  @override
  void initState() {
    super.initState();
    final run = widget.reverse ? _t.reverse(from: 1) : _t.forward();
    run.whenComplete(widget.onDone);
  }

  // The timeline, as fractions of the whole animation.
  static const _binIn = Interval(0, 0.16, curve: Curves.easeOutBack);
  static const _fold = Interval(0, 0.22, curve: Curves.easeInOutCubic);
  static const _crumple = Interval(0.2, 0.42, curve: Curves.easeInCubic);
  static const _toss = Interval(0.42, 0.8);
  static const _lidOpen = Interval(0.38, 0.5, curve: Curves.easeOutBack);
  static const _lidClose = Interval(0.8, 0.88, curve: Curves.bounceOut);
  static const _binOut = Interval(0.9, 1, curve: Curves.easeInCubic);

  static const _binSize = Size(76, 84);
  static const _ball = 52.0;

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return IgnorePointer(
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screen = constraints.biggest;
            // Above the bottom navigation, in the middle.
            final binTopLeft = Offset(
              (screen.width - _binSize.width) / 2,
              screen.height - padding.bottom - 104 - _binSize.height,
            );
            return AnimatedBuilder(
              animation: _t,
              builder: (context, _) => _frame(binTopLeft),
            );
          },
        ),
      ),
    );
  }

  Widget _frame(Offset binTopLeft) {
    final t = _t.value;
    final binShift =
        (1 - _binIn.transform(t)) * 160 + _binOut.transform(t) * 160;
    final lid = -1.15 * _lidOpen.transform(t) * (1 - _lidClose.transform(t));
    final bin = binTopLeft.translate(0, binShift);
    final mouth = bin + Offset(_binSize.width / 2, 14);

    final fold = _fold.transform(t);
    final crumple = _crumple.transform(t);
    final toss = _toss.transform(t);

    // The page: folded to half height, then squeezed into a ball.
    final from = widget.from;
    final folded = Size(from.width, from.height * (1 - 0.5 * fold));
    final size = Size.lerp(folded, const Size.square(_ball), crumple)!;

    // The ball flies along a curve from the page into the bin's mouth.
    final start = from.center;
    final peak = Offset(
      (start.dx + mouth.dx) / 2,
      math.min(start.dy, mouth.dy) - 140,
    );
    final center = _bezier(start, peak, mouth, Curves.easeIn.transform(toss));
    final scale = 1 - 0.35 * toss;
    final spin = crumple * 1.4 + toss * 7;
    final inBin = t >= _toss.end;

    return Stack(
      children: [
        if (!inBin)
          Positioned(
            left: center.dx - size.width / 2,
            top: center.dy - size.height / 2,
            width: size.width,
            height: size.height,
            child: Transform.rotate(
              angle: spin,
              child: Transform.scale(
                scale: scale,
                child: CustomPaint(
                  painter: _PaperPainter(
                    fold: fold,
                    crumple: crumple,
                    fill: widget.paper,
                    ink: widget.ink,
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          left: bin.dx,
          top: bin.dy,
          width: _binSize.width,
          height: _binSize.height,
          child: CustomPaint(
            painter: _BinPainter(lid: lid, fill: widget.bin, ink: widget.ink),
          ),
        ),
      ],
    );
  }

  static Offset _bezier(Offset a, Offset b, Offset c, double u) {
    final v = 1 - u;
    return a * (v * v) + b * (2 * v * u) + c * (u * u);
  }
}

/// A sheet of paper that folds along the middle and crumples into a ball.
class _PaperPainter extends CustomPainter {
  const _PaperPainter({
    required this.fold,
    required this.crumple,
    required this.fill,
    required this.ink,
  });

  final double fold;
  final double crumple;
  final Color fill;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = 10 + (size.shortestSide / 2 - 10) * crumple;
    final shape = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round;

    canvas.drawRRect(shape, Paint()..color = fill);
    // The folded-over half is a little darker, like the paper's back.
    if (fold > 0 && crumple < 1) {
      canvas
        ..drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(0, size.height / 2, size.width, size.height / 2),
            bottomLeft: Radius.circular(radius),
            bottomRight: Radius.circular(radius),
          ),
          Paint()..color = ink.withValues(alpha: 0.08 * fold * (1 - crumple)),
        )
        ..drawLine(
          Offset(4, size.height / 2),
          Offset(size.width - 4, size.height / 2),
          Paint()
            ..color = ink.withValues(alpha: 0.5 * fold * (1 - crumple))
            ..strokeWidth = 1.4,
        );
    }
    // Crinkles appear as it is squeezed.
    if (crumple > 0) {
      final rng = math.Random(7);
      final crinkle = Paint()
        ..color = ink.withValues(alpha: 0.55 * crumple)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round;
      final c = rect.center;
      for (var i = 0; i < 6; i++) {
        final a = rng.nextDouble() * math.pi * 2;
        final r = size.shortestSide * (0.15 + rng.nextDouble() * 0.3);
        final p1 = c + Offset.fromDirection(a, r);
        final p2 = p1 + Offset.fromDirection(a + 2.2, r * 0.7);
        final p3 = p2 + Offset.fromDirection(a - 0.9, r * 0.5);
        canvas.drawPath(
          Path()
            ..moveTo(p1.dx, p1.dy)
            ..lineTo(p2.dx, p2.dy)
            ..lineTo(p3.dx, p3.dy),
          crinkle,
        );
      }
    }
    canvas.drawRRect(shape, line);
  }

  @override
  bool shouldRepaint(_PaperPainter old) =>
      old.fold != fold ||
      old.crumple != crumple ||
      old.fill != fill ||
      old.ink != ink;
}

/// A sketched wastebasket whose lid swings open on its left hinge.
class _BinPainter extends CustomPainter {
  const _BinPainter({required this.lid, required this.fill, required this.ink});

  /// Lid angle in radians; negative opens it.
  final double lid;
  final Color fill;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // Body: tapers toward the bottom, with ribs.
    const top = 16.0;
    final body = Path()
      ..moveTo(6, top)
      ..lineTo(w - 6, top)
      ..lineTo(w - 12, h - 2)
      ..quadraticBezierTo(w - 13, h, w - 16, h)
      ..lineTo(16, h)
      ..quadraticBezierTo(13, h, 12, h - 2)
      ..close();
    canvas
      ..drawShadow(body, Colors.black, 4, false)
      ..drawPath(body, Paint()..color = fill)
      ..drawPath(body, line);
    final rib = Paint()
      ..color = ink
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (final x in [0.32, 0.5, 0.68]) {
      canvas.drawLine(
        Offset(w * x, top + 10),
        Offset(w * (0.5 + (x - 0.5) * 0.8), h - 10),
        rib,
      );
    }

    // Lid, hinged on the left.
    final lidRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, -8, w - 6, 9),
      const Radius.circular(3),
    );
    final handle = RRect.fromRectAndRadius(
      Rect.fromLTWH((w - 6) / 2 - 10, -14, 20, 7),
      const Radius.circular(3),
    );
    canvas
      ..save()
      ..translate(3, top - 2)
      ..rotate(lid)
      ..drawRRect(lidRect, Paint()..color = fill)
      ..drawRRect(lidRect, line)
      ..drawRRect(handle, line)
      ..restore();
  }

  @override
  bool shouldRepaint(_BinPainter old) =>
      old.lid != lid || old.fill != fill || old.ink != ink;
}
