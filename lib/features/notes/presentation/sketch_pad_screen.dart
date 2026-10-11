import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../canvas/domain/board.dart';
import '../../canvas/presentation/board_painters.dart';
import '../../canvas/presentation/pen_tools.dart';
import '../data/notes_repository.dart';
import '../domain/note.dart';

/// A full-screen page to draw on, with pen, eraser, undo and redo.
///
/// Leaving always keeps the drawing: with [createNote] it becomes a new note
/// (opened next so it can be titled); otherwise the strokes are returned to
/// the caller as the route result.
class SketchPadScreen extends StatefulWidget {
  const SketchPadScreen({
    super.key,
    this.initial = const [],
    this.createNote = false,
  });

  final List<BoardStroke> initial;
  final bool createNote;

  @override
  State<SketchPadScreen> createState() => _SketchPadScreenState();
}

class _SketchPadScreenState extends State<SketchPadScreen> {
  late List<BoardStroke> _strokes = widget.initial;
  final _undo = <List<BoardStroke>>[];
  final _redo = <List<BoardStroke>>[];

  bool _erasing = false;
  Color _color = penColors.first;
  double _width = penWidths[1];

  List<Offset>? _drawing;
  Offset? _lastErase;
  List<BoardStroke>? _eraseStart;
  bool _closing = false;

  void _commit(List<BoardStroke> next, {List<BoardStroke>? before}) {
    final previous = before ?? _strokes;
    if (identical(previous, next)) return;
    setState(() {
      _undo.add(previous);
      _redo.clear();
      _strokes = next;
    });
  }

  void _step(List<List<BoardStroke>> from, List<List<BoardStroke>> to) {
    if (from.isEmpty) return;
    setState(() {
      to.add(_strokes);
      _strokes = from.removeLast();
    });
  }

  void _eraseAt(Offset p) {
    const radius = 12.0;
    final from = _lastErase ?? p;
    _lastErase = p;
    final steps = math.max(1, ((p - from).distance / radius).ceil());
    final probes = [
      for (var i = 0; i <= steps; i++) Offset.lerp(from, p, i / steps)!,
    ];
    final kept = [
      for (final s in _strokes)
        if (!probes.any((probe) => strokeHitsPoint(s, probe, radius))) s,
    ];
    if (kept.length != _strokes.length) setState(() => _strokes = kept);
  }

  void _start(Offset p) {
    if (_erasing) {
      _eraseStart = _strokes;
      _eraseAt(p);
    } else {
      setState(() => _drawing = [p]);
    }
  }

  void _move(Offset p) {
    final points = _drawing;
    if (_erasing) {
      _eraseAt(p);
    } else if (points != null && (points.last - p).distance > 1.5) {
      setState(() => points.add(p));
    }
  }

  void _end() {
    final points = _drawing;
    if (_erasing) {
      final before = _eraseStart;
      _eraseStart = null;
      _lastErase = null;
      if (before != null) _commit(_strokes, before: before);
    } else if (points != null) {
      _drawing = null;
      _commit([
        ..._strokes,
        BoardStroke(
          id: newBoardId(),
          points: List.unmodifiable(points),
          color: _color.toARGB32(),
          width: _width,
        ),
      ]);
    }
  }

  void _finish() {
    if (_closing) return;
    _closing = true;
    if (!widget.createNote) {
      context.pop(_strokes);
      return;
    }
    if (_strokes.isEmpty) {
      context.pop();
      return;
    }
    final repo = NotesRepository.instance;
    final note = Note.create(color: repo.notes.length % AppColors.notes.length)
        .copyWith(sketch: _strokes);
    repo.save(note);
    context.pushReplacement(AppRoutes.noteById(note.id));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sketch'),
          actions: [
            IconButton(
              tooltip: 'Undo',
              icon: const Icon(Icons.undo_rounded),
              onPressed: _undo.isEmpty ? null : () => _step(_undo, _redo),
            ),
            IconButton(
              tooltip: 'Redo',
              icon: const Icon(Icons.redo_rounded),
              onPressed: _redo.isEmpty ? null : () => _step(_redo, _undo),
            ),
            IconButton(
              tooltip: 'Clear page',
              icon: const Icon(Icons.layers_clear_outlined),
              onPressed: _strokes.isEmpty ? null : () => _commit(const []),
            ),
            TextButton(onPressed: _finish, child: const Text('Done')),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ClipRect(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  dragStartBehavior: DragStartBehavior.down,
                  onPanStart: (d) => _start(d.localPosition),
                  onPanUpdate: (d) => _move(d.localPosition),
                  onPanEnd: (_) => _end(),
                  onTapUp: (d) {
                    _start(d.localPosition);
                    _end();
                  },
                  child: Semantics(
                    label: 'Drawing area',
                    // Paper and finished strokes are cached; only the stroke
                    // being drawn repaints as the pen moves.
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: DotGridPainter(
                                color: scheme.outlineVariant,
                              ),
                              foregroundPainter: StrokesPainter(
                                strokes: _strokes,
                                ink: scheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: CustomPaint(
                            painter: StrokesPainter(
                              strokes: const <BoardStroke>[],
                              ink: scheme.onSurface,
                              current: _drawing,
                              currentColor: _color,
                              currentWidth: _width,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: ToolBar(
                  children: [
                    ToolButton(
                      tooltip: 'Pen',
                      selected: !_erasing,
                      icon: const Icon(Icons.draw_outlined),
                      onPressed: () => setState(() => _erasing = false),
                    ),
                    ToolButton(
                      tooltip: 'Eraser',
                      selected: _erasing,
                      icon: const Icon(Icons.cleaning_services_outlined),
                      onPressed: () => setState(() => _erasing = true),
                    ),
                    if (!_erasing) ...[
                      const ToolBarDivider(),
                      ...penOptions(
                        context: context,
                        color: _color,
                        width: _width,
                        onColor: (c) => setState(() => _color = c),
                        onWidth: (w) => setState(() => _width = w),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
