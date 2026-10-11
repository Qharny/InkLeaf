import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/sketch_styles.dart';
import '../../../core/widgets/text_entry_dialog.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/domain/note.dart';
import '../../notes/presentation/note_card.dart';
import '../data/boards_repository.dart';
import '../domain/board.dart';
import 'board_painters.dart';
import 'pen_tools.dart';

enum _Tool { select, pen, eraser, connect }

const _minScale = 0.25;
const _maxScale = 2.5;
const _maxUndo = 100;

/// A board to think visually on: sticky notes and note cards you can move
/// and resize, arrows between them, and freehand pen drawing. Pinch or drag
/// the background to move around. Every change saves straight away.
class CanvasEditorScreen extends StatefulWidget {
  const CanvasEditorScreen({super.key, required this.boardId});

  final String boardId;

  @override
  State<CanvasEditorScreen> createState() => _CanvasEditorScreenState();
}

class _CanvasEditorScreenState extends State<CanvasEditorScreen> {
  final _repo = BoardsRepository.instance;
  final _view = TransformationController();
  late Board _board;
  late final bool _missing;
  bool _deleted = false;

  final _undo = <Board>[];
  final _redo = <Board>[];

  _Tool _tool = _Tool.select;
  String? _selectedCard;
  String? _selectedLink;

  /// First card tapped with the connect tool.
  String? _linkFrom;

  /// The board before the current drag, erase or resize, for undo.
  Board? _gestureStart;

  /// Points of the stroke being drawn.
  List<Offset>? _drawing;

  /// Where the eraser last touched, so a fast swipe erases everything in
  /// between instead of skipping over strokes.
  Offset? _lastErase;
  Color _penColor = penColors.first;
  double _penWidth = penWidths[1];

  Size _viewport = Size.zero;
  bool _placed = false;

  @override
  void initState() {
    super.initState();
    final board = _repo.byId(widget.boardId);
    _missing = board == null;
    _board = board ?? Board.create();
  }

  @override
  void dispose() {
    _view.dispose();
    super.dispose();
  }

  double get _scale => _view.value.getMaxScaleOnAxis();

  Offset get _viewCenter => _view.toScene(_viewport.center(Offset.zero));

  // ---- Editing ------------------------------------------------------------

  /// Makes [next] the board, saving it and recording [before] (or the
  /// current board) for undo.
  void _commit(Board next, {Board? before}) {
    final previous = before ?? _board;
    if (identical(previous, next)) return;
    setState(() {
      _undo.add(previous);
      if (_undo.length > _maxUndo) _undo.removeAt(0);
      _redo.clear();
      _board = next.copyWith(updatedAt: DateTime.now());
    });
    _repo.save(_board);
  }

  void _undoLast() => _step(_undo, _redo);

  void _redoLast() => _step(_redo, _undo);

  void _step(List<Board> from, List<Board> to) {
    if (from.isEmpty) return;
    setState(() {
      to.add(_board);
      _board = from.removeLast().copyWith(updatedAt: DateTime.now());
      if (_selectedCard != null && _board.card(_selectedCard!) == null) {
        _selectedCard = null;
      }
      if (!_board.links.any((l) => l.id == _selectedLink)) {
        _selectedLink = null;
      }
      if (_linkFrom != null && _board.card(_linkFrom!) == null) {
        _linkFrom = null;
      }
    });
    _repo.save(_board);
  }

  void _select({String? card, String? link}) => setState(() {
    _selectedCard = card;
    _selectedLink = link;
  });

  void _setTool(_Tool tool) => setState(() {
    _tool = tool;
    _linkFrom = null;
    if (tool != _Tool.select) _select();
  });

  /// Where a new card of [size] goes: the middle of the screen, nudged so
  /// cards added one after another don't stack exactly.
  Offset _newCardPosition(Size size) {
    final nudge = (_board.cards.length % 6) * 40.0;
    final c = _viewCenter;
    return Offset(
      (c.dx - size.width / 2 + nudge).clamp(0, boardSize - size.width),
      (c.dy - size.height / 2 + nudge).clamp(0, boardSize - size.height),
    );
  }

  Future<void> _addSticky() async {
    final at = _newCardPosition(const Size(180, 140));
    final card = BoardCard(
      id: newBoardId(),
      kind: BoardCardKind.sticky,
      color: _board.cards.length % AppColors.notes.length,
      x: at.dx,
      y: at.dy,
    );
    _setTool(_Tool.select);
    _commit(_board.addCard(card));
    _select(card: card.id);
    await _editSticky(card);
  }

  Future<void> _addNoteCard() async {
    final note = await showModalBottomSheet<Note>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NotePicker(notes: NotesRepository.instance.notes),
    );
    if (note == null || !mounted) return;
    final at = _newCardPosition(const Size(200, 150));
    final card = BoardCard(
      id: newBoardId(),
      kind: BoardCardKind.note,
      noteId: note.id,
      color: note.color,
      x: at.dx,
      y: at.dy,
      width: 200,
      height: 150,
    );
    _setTool(_Tool.select);
    _commit(_board.addCard(card));
    _select(card: card.id);
  }

  Future<void> _editSticky(BoardCard card) async {
    final text = await showTextEntryDialog(
      context,
      title: 'Sticky note',
      initial: card.text,
      hint: 'Write something…',
      multiline: true,
    );
    final current = _board.card(card.id);
    if (text == null || current == null || !mounted) return;
    if (text.trim() == current.text) return;
    _commit(_board.updateCard(current.copyWith(text: text.trim())));
  }

  void _openNote(BoardCard card) {
    final note = NotesRepository.instance.byId(card.noteId ?? '');
    if (note == null || note.inTrash) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('That note was deleted')));
      return;
    }
    context.push(AppRoutes.noteById(note.id));
  }

  void _openCard(BoardCard card) =>
      card.kind == BoardCardKind.sticky ? _editSticky(card) : _openNote(card);

  void _pickCardColor(BoardCard card) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          child: NoteColorPicker(
            selected: card.color,
            onSelected: (color) {
              Navigator.of(sheetContext).pop();
              final current = _board.card(card.id);
              if (current != null) {
                _commit(_board.updateCard(current.copyWith(color: color)));
              }
            },
          ),
        ),
      ),
    );
  }

  void _deleteSelected() {
    final card = _selectedCard, link = _selectedLink;
    if (card != null) _commit(_board.removeCard(card));
    if (link != null) _commit(_board.removeLink(link));
    _select();
  }

  Future<void> _rename() async {
    final title = await showTextEntryDialog(
      context,
      title: 'Name this canvas',
      initial: _board.title == Board.defaultTitle ? '' : _board.title,
      hint: Board.defaultTitle,
    );
    if (title == null || !mounted) return;
    final clean = title.trim().isEmpty ? Board.defaultTitle : title.trim();
    if (clean != _board.title) _commit(_board.copyWith(title: clean));
  }

  Future<void> _deleteBoard() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this canvas?'),
        content: const Text(
          'Its cards and drawings go too. Linked notes are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!(ok ?? false) || !mounted) return;
    _deleted = true;
    _repo.delete(_board.id);
    context.pop();
  }

  void _onClosed() {
    // A canvas opened and left untouched isn't worth keeping.
    if (!_deleted && _board.isEmpty && _board.title == Board.defaultTitle) {
      _repo.delete(_board.id);
    }
  }

  // ---- View ---------------------------------------------------------------

  /// Zooms to show everything on the board, or the middle of an empty one.
  void _fit() {
    if (_viewport.isEmpty) return;
    final target =
        _board.contentBounds?.inflate(48) ??
        Rect.fromCenter(
          center: const Offset(boardSize / 2, boardSize / 2),
          width: _viewport.width,
          height: _viewport.height,
        );
    final s = math
        .min(_viewport.width / target.width, _viewport.height / target.height)
        .clamp(_minScale, 1.0);
    _view.value = Matrix4.identity()
      ..setEntry(0, 0, s)
      ..setEntry(1, 1, s)
      ..setEntry(0, 3, _viewport.width / 2 - s * target.center.dx)
      ..setEntry(1, 3, _viewport.height / 2 - s * target.center.dy);
  }

  // ---- Gestures -----------------------------------------------------------

  void _onBackgroundTap(TapUpDetails details) {
    if (_tool == _Tool.connect) {
      setState(() => _linkFrom = null);
      return;
    }
    final p = details.localPosition;
    final tolerance = 16 / _scale;
    for (final link in _board.links.reversed) {
      final segment = linkSegment(_board, link);
      if (segment != null &&
          distanceToSegment(p, segment.$1, segment.$2) <= tolerance) {
        _select(link: link.id);
        return;
      }
    }
    _select();
  }

  void _onCardTap(BoardCard card) {
    if (_tool != _Tool.connect) {
      _select(card: card.id);
      return;
    }
    final from = _linkFrom;
    if (from == null) {
      setState(() => _linkFrom = card.id);
    } else if (from == card.id) {
      setState(() => _linkFrom = null);
    } else {
      _commit(_board.addLink(from, card.id));
      setState(() => _linkFrom = null);
    }
  }

  void _onCardDragStart(BoardCard card) {
    _gestureStart = _board;
    setState(() {
      _board = _board.bringToFront(card.id);
      _selectedCard = card.id;
      _selectedLink = null;
    });
  }

  void _onCardDrag(String id, Offset delta) {
    final c = _board.card(id);
    if (c == null) return;
    setState(() {
      _board = _board.updateCard(
        c.copyWith(
          x: (c.x + delta.dx).clamp(0, boardSize - c.width),
          y: (c.y + delta.dy).clamp(0, boardSize - c.height),
        ),
      );
    });
  }

  void _onCardResize(String id, Offset delta) {
    final c = _board.card(id);
    if (c == null) return;
    setState(() {
      _board = _board.updateCard(
        c.copyWith(
          width: (c.width + delta.dx).clamp(
            BoardCard.minWidth,
            math.min(BoardCard.maxSide, boardSize - c.x),
          ),
          height: (c.height + delta.dy).clamp(
            BoardCard.minHeight,
            math.min(BoardCard.maxSide, boardSize - c.y),
          ),
        ),
      );
    });
  }

  void _endGesture() {
    final before = _gestureStart;
    _gestureStart = null;
    _lastErase = null;
    if (before != null) _commit(_board, before: before);
  }

  void _eraseAt(Offset p) {
    final radius = 12 / _scale;
    final from = _lastErase ?? p;
    _lastErase = p;
    final steps = math.max(1, ((p - from).distance / radius).ceil());
    final probes = [
      for (var i = 0; i <= steps; i++) Offset.lerp(from, p, i / steps)!,
    ];
    final hit = {
      for (final s in _board.strokes)
        if (probes.any((probe) => strokeHitsPoint(s, probe, radius))) s.id,
    };
    if (hit.isNotEmpty) setState(() => _board = _board.removeStrokes(hit));
  }

  void _onDrawStart(DragStartDetails d) {
    if (_tool == _Tool.pen) {
      setState(() => _drawing = [d.localPosition]);
    } else {
      _gestureStart = _board;
      _eraseAt(d.localPosition);
    }
  }

  void _onDrawUpdate(DragUpdateDetails d) {
    final points = _drawing;
    if (_tool == _Tool.eraser) {
      _eraseAt(d.localPosition);
    } else if (points != null &&
        (points.last - d.localPosition).distance > 1.5 / _scale) {
      setState(() => points.add(d.localPosition));
    }
  }

  void _onDrawEnd([DragEndDetails? _]) {
    final points = _drawing;
    if (_tool == _Tool.eraser) {
      _endGesture();
    } else if (points != null) {
      _drawing = null;
      _commit(
        _board.addStroke(
          BoardStroke(
            id: newBoardId(),
            points: List.unmodifiable(points),
            color: _penColor.toARGB32(),
            width: _penWidth,
          ),
        ),
      );
    }
  }

  void _onDrawTap(TapUpDetails d) {
    if (_tool == _Tool.pen) {
      _drawing = [d.localPosition];
      _onDrawEnd();
    } else {
      _gestureStart = _board;
      _eraseAt(d.localPosition);
      _endGesture();
    }
  }

  // ---- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_missing) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(
            'This canvas no longer exists.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _onClosed();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Semantics(
            button: true,
            hint: 'Rename',
            child: GestureDetector(
              onTap: _rename,
              child: Text(_board.title, overflow: TextOverflow.ellipsis),
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Undo',
              icon: const Icon(Icons.undo_rounded),
              onPressed: _undo.isEmpty ? null : _undoLast,
            ),
            IconButton(
              tooltip: 'Redo',
              icon: const Icon(Icons.redo_rounded),
              onPressed: _redo.isEmpty ? null : _redoLast,
            ),
            IconButton(
              tooltip: 'Fit to screen',
              icon: const Icon(Icons.fit_screen_outlined),
              onPressed: _fit,
            ),
            PopupMenuButton<VoidCallback>(
              tooltip: 'More',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (action) => action(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: _rename,
                  child: const ListTile(
                    leading: Icon(Icons.drive_file_rename_outline),
                    title: Text('Rename'),
                  ),
                ),
                PopupMenuItem(
                  value: _deleteBoard,
                  child: const ListTile(
                    leading: Icon(Icons.delete_outline_rounded),
                    title: Text('Delete canvas'),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Stack(
          children: [
            Positioned.fill(child: _buildBoard(context)),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: SafeArea(top: false, child: _buildControls(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final drawing = _tool == _Tool.pen || _tool == _Tool.eraser;
    final selecting = _tool == _Tool.select;

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.biggest;
        if (!_placed) {
          _placed = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
        }
        return InteractiveViewer(
          transformationController: _view,
          constrained: false,
          minScale: _minScale,
          maxScale: _maxScale,
          boundaryMargin: const EdgeInsets.all(240),
          panEnabled: !drawing,
          scaleEnabled: !drawing,
          child: SizedBox.square(
            dimension: boardSize,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: _onBackgroundTap,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: DotGridPainter(color: scheme.outlineVariant),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: LinksPainter(
                        board: _board,
                        color: scheme.outline,
                        accent: scheme.primary,
                        selectedId: _selectedLink,
                      ),
                    ),
                  ),
                ),
                for (final card in _board.cards)
                  Positioned.fromRect(
                    key: ValueKey('board-card-${card.id}'),
                    rect: card.rect,
                    child: GestureDetector(
                      // Follow the finger from touch-down, not from where the
                      // drag was recognized, so the card doesn't lag.
                      dragStartBehavior: DragStartBehavior.down,
                      onTap: () => _onCardTap(card),
                      onDoubleTap: selecting ? () => _openCard(card) : null,
                      onPanStart: selecting
                          ? (_) => _onCardDragStart(card)
                          : null,
                      onPanUpdate: selecting
                          ? (d) => _onCardDrag(card.id, d.delta)
                          : null,
                      onPanEnd: selecting ? (_) => _endGesture() : null,
                      child: _BoardCardView(
                        card: card,
                        selected: card.id == _selectedCard,
                        linkSource: card.id == _linkFrom,
                        onResizeStart: selecting && card.id == _selectedCard
                            ? () => _gestureStart = _board
                            : null,
                        onResize: (delta) => _onCardResize(card.id, delta),
                        onResizeEnd: _endGesture,
                      ),
                    ),
                  ),
                // Finished strokes are cached; only the one being drawn
                // repaints as the pen moves.
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: StrokesPainter(
                          strokes: _board.strokes,
                          ink: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_drawing != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: StrokesPainter(
                          strokes: const <BoardStroke>[],
                          ink: scheme.onSurface,
                          current: _drawing,
                          currentColor: _penColor,
                          currentWidth: _penWidth,
                        ),
                      ),
                    ),
                  ),
                if (drawing)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      dragStartBehavior: DragStartBehavior.down,
                      onPanStart: _onDrawStart,
                      onPanUpdate: _onDrawUpdate,
                      onPanEnd: _onDrawEnd,
                      onTapUp: _onDrawTap,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls(BuildContext context) {
    final hint = switch (_tool) {
      _Tool.connect when _linkFrom == null => 'Tap a card to start an arrow',
      _Tool.connect => 'Now tap the card it points to',
      _Tool.eraser => 'Drag over drawings to erase them',
      _ when _board.isEmpty => 'Add a sticky note or one of your notes',
      _ => null,
    };
    final selectedCard = _selectedCard == null
        ? null
        : _board.card(_selectedCard!);
    final hasSelection = selectedCard != null || _selectedLink != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Semantics(
              liveRegion: true,
              child: MarkerHighlight(
                child: Text(
                  hint,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
          ),
        if (_tool == _Tool.select && hasSelection)
          ToolBar(
            seed: 4,
            children: [
              if (selectedCard != null) ...[
                if (selectedCard.kind == BoardCardKind.sticky)
                  IconButton(
                    tooltip: 'Edit text',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editSticky(selectedCard),
                  )
                else
                  IconButton(
                    tooltip: 'Open note',
                    icon: const Icon(Icons.open_in_new_rounded),
                    onPressed: () => _openNote(selectedCard),
                  ),
                IconButton(
                  tooltip: 'Color',
                  icon: const Icon(Icons.palette_outlined),
                  onPressed: () => _pickCardColor(selectedCard),
                ),
                IconButton(
                  tooltip: 'Draw an arrow from here',
                  icon: const Icon(Icons.arrow_right_alt_rounded),
                  onPressed: () => setState(() {
                    _tool = _Tool.connect;
                    _linkFrom = selectedCard.id;
                    _select();
                  }),
                ),
              ],
              IconButton(
                tooltip: selectedCard != null ? 'Delete card' : 'Delete arrow',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: _deleteSelected,
              ),
            ],
          ),
        if (_tool == _Tool.pen)
          ToolBar(
            seed: 6,
            children: penOptions(
              context: context,
              color: _penColor,
              width: _penWidth,
              onColor: (c) => setState(() => _penColor = c),
              onWidth: (w) => setState(() => _penWidth = w),
            ),
          ),
        const SizedBox(height: 8),
        ToolBar(
          seed: 2,
          children: [
            _toolButton(
              _Tool.select,
              Icons.pan_tool_alt_outlined,
              'Select and move',
            ),
            _toolButton(_Tool.pen, Icons.draw_outlined, 'Pen'),
            _toolButton(
              _Tool.eraser,
              Icons.cleaning_services_outlined,
              'Eraser',
            ),
            _toolButton(
              _Tool.connect,
              Icons.arrow_right_alt_rounded,
              'Connect cards',
            ),
            const ToolBarDivider(),
            IconButton(
              tooltip: 'Add sticky note',
              icon: const Icon(Icons.sticky_note_2_outlined),
              onPressed: _addSticky,
            ),
            IconButton(
              tooltip: 'Add a note',
              icon: const Icon(Icons.note_add_outlined),
              onPressed: _addNoteCard,
            ),
          ],
        ),
      ],
    );
  }

  Widget _toolButton(_Tool tool, IconData icon, String label) => ToolButton(
    tooltip: label,
    selected: _tool == tool,
    icon: Icon(icon),
    onPressed: () => _setTool(tool),
  );
}

/// A card's face: sticky text, or a live preview of the linked note.
class _BoardCardView extends StatelessWidget {
  const _BoardCardView({
    required this.card,
    required this.selected,
    required this.linkSource,
    required this.onResizeStart,
    required this.onResize,
    required this.onResizeEnd,
  });

  final BoardCard card;
  final bool selected;
  final bool linkSource;

  /// Null hides the resize handle.
  final VoidCallback? onResizeStart;
  final ValueChanged<Offset> onResize;
  final VoidCallback onResizeEnd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final highlighted = selected || linkSource;
    final resizeStart = onResizeStart;
    return Stack(
      children: [
        Positioned.fill(
          child: Material(
            color: noteFill(context, card.color),
            clipBehavior: Clip.antiAlias,
            shape: SketchBorder(
              side: BorderSide(
                color: highlighted ? scheme.primary : scheme.outline,
                width: highlighted ? 3 : SketchStyles.strokeWidth,
              ),
              seed: card.id.hashCode,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: card.kind == BoardCardKind.sticky
                  ? _StickyFace(card: card)
                  : _NoteFace(noteId: card.noteId),
            ),
          ),
        ),
        if (resizeStart != null)
          Positioned(
            right: 0,
            bottom: 0,
            child: Semantics(
              label: 'Resize',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                dragStartBehavior: DragStartBehavior.down,
                onPanStart: (_) => resizeStart(),
                onPanUpdate: (d) => onResize(d.delta),
                onPanEnd: (_) => onResizeEnd(),
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.open_in_full_rounded,
                        size: 18,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StickyFace extends StatelessWidget {
  const _StickyFace({required this.card});

  final BoardCard card;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (card.text.isEmpty) {
      return Text(
        'Double-tap to write',
        style: text.bodyLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    return Text(card.text, style: text.bodyLarge);
  }
}

class _NoteFace extends StatelessWidget {
  const _NoteFace({required this.noteId});

  final String? noteId;

  @override
  Widget build(BuildContext context) {
    final repo = NotesRepository.instance;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final note = repo.byId(noteId ?? '');
        final gone = note == null || note.inTrash;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  'Note',
                  style: text.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (gone)
              Text(
                'This note was deleted',
                style: text.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              )
            else ...[
              Text(
                note.displayTitle,
                style: text.titleLarge?.copyWith(fontSize: 17),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (note.preview.isNotEmpty)
                Flexible(
                  child: Text(
                    note.preview,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.fade,
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

/// Bottom sheet listing notes to place on the board.
class _NotePicker extends StatelessWidget {
  const _NotePicker({required this.notes});

  final List<Note> notes;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text('Add a note to the canvas', style: text.titleLarge),
            ),
            if (notes.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Text(
                  'You have no notes yet. Write one with the + button, then '
                  'bring it here.',
                  style: text.bodyLarge,
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: notes.length,
                  itemBuilder: (context, i) => ListTile(
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundColor: noteFill(context, notes[i].color),
                    ),
                    title: Text(
                      notes[i].displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: notes[i].preview.isEmpty
                        ? null
                        : Text(
                            notes[i].preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    onTap: () => Navigator.of(context).pop(notes[i]),
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
