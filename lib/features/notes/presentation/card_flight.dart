import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/note.dart';
import 'note_card.dart';

/// Moves a copy of [note]'s card from [from] to [to] over everything, so
/// a card that changes place (pinned, unpinned) is seen travelling there.
/// Hide the real card at [to] until this completes. Skipped with reduced
/// motion on.
Future<void> flyNoteCard(
  BuildContext context, {
  required Note note,
  required Rect from,
  required Rect to,
}) => _overlay(
  context,
  duration: const Duration(milliseconds: 280),
  curve: Curves.easeInOutCubic,
  builder: (t) => Positioned.fromRect(
    rect: Rect.lerp(from, to, t)!,
    child: NoteCard(note: note),
  ),
);

/// Shrinks and fades a copy of [note]'s card where it was ([from]), for a
/// note that leaves a list without being deleted.
Future<void> vanishNoteCard(
  BuildContext context, {
  required Note note,
  required Rect from,
}) => _overlay(
  context,
  duration: const Duration(milliseconds: 220),
  curve: Curves.easeInCubic,
  builder: (t) => Positioned.fromRect(
    rect: from,
    child: Opacity(
      opacity: 1 - t,
      child: Transform.scale(
        scale: 1 - 0.15 * t,
        child: NoteCard(note: note, fixedHeight: false, previewLines: 2),
      ),
    ),
  ),
);

Future<void> _overlay(
  BuildContext context, {
  required Duration duration,
  required Curve curve,
  required Widget Function(double t) builder,
}) {
  if (MediaQuery.disableAnimationsOf(context)) return Future.value();
  final overlay = Overlay.of(context, rootOverlay: true);
  final done = Completer<void>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Flight(
      duration: duration,
      curve: curve,
      builder: builder,
      onDone: () {
        entry.remove();
        done.complete();
      },
    ),
  );
  overlay.insert(entry);
  return done.future;
}

class _Flight extends StatefulWidget {
  const _Flight({
    required this.duration,
    required this.curve,
    required this.builder,
    required this.onDone,
  });

  final Duration duration;
  final Curve curve;
  final Widget Function(double t) builder;
  final VoidCallback onDone;

  @override
  State<_Flight> createState() => _FlightState();
}

class _FlightState extends State<_Flight> with SingleTickerProviderStateMixin {
  late final _t = AnimationController(vsync: this, duration: widget.duration)
    ..forward().whenComplete(widget.onDone);
  late final _curved = CurvedAnimation(parent: _t, curve: widget.curve);

  @override
  void dispose() {
    _curved.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _curved,
        builder: (context, _) =>
            Stack(children: [widget.builder(_curved.value)]),
      ),
    );
  }
}
