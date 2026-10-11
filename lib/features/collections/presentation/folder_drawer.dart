import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/sketch_styles.dart';
import '../domain/collection.dart';
import 'collection_widgets.dart';

/// How much of each folder shows before the next one covers it.
const _slice = 100.0;
const _folderHeight = 200.0;
const _tabHeight = 32.0;

/// Where the folder's front panel starts; papers peek out above it.
const _frontTop = _tabHeight + 20;

/// Folders scrolled past the top squeeze into a stack of edges this thick.
const _pinGap = 6.0;
const _maxPinned = 5;
const _topPad = 16.0;
const _side = 16.0;
const _lipHeight = 46.0;

/// Hero tags shared with the collection page, so the folder flies into it.
String folderHeroTag(String id) => 'folder-$id';
String folderTabHeroTag(String id) => 'folder-tab-$id';

/// Collections as manila folders standing in an open drawer, tabs staggered
/// left, middle and right like real files.
///
/// The drawer slides open and the folders settle in one after another;
/// scrolling squeezes passed folders into a stack at the top; pressing a
/// folder lifts it; long-pressing picks it up to reorder. [FolderDrawerState]
/// also animates folders dropping in ([FolderDrawerState.dropIn]) and
/// sliding out ([FolderDrawerState.removeAnimated]). With reduced motion on,
/// all of this is skipped.
class FolderDrawer extends StatefulWidget {
  const FolderDrawer({
    super.key,
    required this.collections,
    required this.noteCount,
    required this.onOpen,
    required this.onMore,
    required this.onReorder,
  });

  /// Front of the drawer first.
  final List<Collection> collections;
  final int Function(Collection) noteCount;
  final ValueChanged<Collection> onOpen;
  final ValueChanged<Collection> onMore;
  final void Function(int from, int to) onReorder;

  @override
  State<FolderDrawer> createState() => FolderDrawerState();
}

class FolderDrawerState extends State<FolderDrawer>
    with TickerProviderStateMixin {
  final _scroll = ScrollController();
  final _contentKey = GlobalKey();
  late final _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final _drop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final _remove = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  String? _dropping;
  String? _removing;
  bool _reduceMotion = false;

  // Reordering.
  int? _dragFrom;
  int _dragTo = 0;
  double _dragTop = 0;
  double _grab = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_entry.status == AnimationStatus.dismissed) {
      _reduceMotion ? _entry.value = 1 : _entry.forward();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _entry.dispose();
    _drop.dispose();
    _remove.dispose();
    super.dispose();
  }

  /// Drops the folder for [id] into the drawer from above.
  void dropIn(String id) {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (_reduceMotion) return;
    setState(() => _dropping = id);
    _drop.forward(from: 0);
  }

  /// Slides the folder for [id] out sideways, then calls [onRemoved], which
  /// should take it out of [FolderDrawer.collections].
  Future<void> removeAnimated(String id, VoidCallback onRemoved) async {
    if (!_reduceMotion) {
      setState(() => _removing = id);
      await _remove.forward(from: 0);
    }
    onRemoved();
    if (mounted) {
      setState(() {
        _removing = null;
        _remove.value = 0;
      });
    }
  }

  double get _scrollOffset => _scroll.hasClients ? _scroll.offset : 0;

  /// Extra space above the first folder when there are too few to fill the
  /// drawer, so the folders rest on its bottom like real ones.
  double _sink = 0;

  /// Where a folder in [slot] rests: its place in the drawer, unless it has
  /// scrolled past the top, where it joins the squeezed stack.
  double _restingTop(int slot, double scroll) => math.max(
    _sink + _topPad + slot * _slice,
    scroll + _topPad + math.min(slot, _maxPinned) * _pinGap,
  );

  /// The slot a folder shows in while another is being dragged over it.
  int _visualSlot(int i) {
    final from = _dragFrom;
    if (from == null || i == from) return i;
    if (from < _dragTo && i > from && i <= _dragTo) return i - 1;
    if (from > _dragTo && i >= _dragTo && i < from) return i + 1;
    return i;
  }

  Offset? _contentPosition(Offset global) {
    final box = _contentKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.globalToLocal(global);
  }

  void _startDrag(int i, LongPressStartDetails details) {
    final local = _contentPosition(details.globalPosition);
    if (local == null) return;
    final top = _restingTop(i, _scrollOffset);
    HapticFeedback.mediumImpact();
    setState(() {
      _dragFrom = i;
      _dragTo = i;
      _dragTop = top;
      _grab = local.dy - top;
    });
  }

  void _updateDrag(LongPressMoveUpdateDetails details) {
    final local = _contentPosition(details.globalPosition);
    if (local == null || _dragFrom == null) return;
    final last = widget.collections.length - 1;
    setState(() {
      _dragTop = local.dy - _grab;
      _dragTo = ((_dragTop - _sink - _topPad) / _slice).round().clamp(0, last);
    });
  }

  void _endDrag() {
    final from = _dragFrom;
    if (from == null) return;
    final to = _dragTo;
    setState(() => _dragFrom = null);
    if (from != to) widget.onReorder(from, to);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = widget.collections.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        // The front folder's foot tucks in behind the drawer front.
        final content =
            _topPad + (count - 1) * _slice + _folderHeight + _lipHeight - 24;
        _sink = math.max(0, constraints.maxHeight - content);
        return Stack(
          children: [
            // The inside of the drawer.
            Positioned.fill(
              child: ColoredBox(color: scheme.surfaceContainerHigh),
            ),
            Positioned.fill(
              child: SingleChildScrollView(
                controller: _scroll,
                physics: _dragFrom != null
                    ? const NeverScrollableScrollPhysics()
                    : null,
                child: SizedBox(
                  key: _contentKey,
                  width: constraints.maxWidth,
                  height: math.max(content, constraints.maxHeight),
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _scroll,
                      _entry,
                      _drop,
                      _remove,
                    ]),
                    builder: (context, _) => Stack(
                      children: _buildFolders(constraints.maxWidth - _side * 2),
                    ),
                  ),
                ),
              ),
            ),
            // The drawer front slides out first, then the folders rise.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                    .animate(
                      CurvedAnimation(
                        parent: _entry,
                        curve: const Interval(
                          0,
                          0.35,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                    ),
                child: const _DrawerFront(),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildFolders(double width) {
    final scroll = _scrollOffset;
    final items = widget.collections;
    final from = _dragFrom;
    // Later folders sit in front; the one being dragged is on top of all.
    final paintOrder = [
      for (var i = 0; i < items.length; i++)
        if (i != from) i,
      ?from,
    ];
    return [
      for (final i in paintOrder) _buildFolder(i, items[i], width, scroll),
    ];
  }

  Widget _buildFolder(int i, Collection c, double width, double scroll) {
    final dragging = i == _dragFrom;
    var top = dragging ? _dragTop : _restingTop(_visualSlot(i), scroll);
    var dx = 0.0, angle = 0.0, opacity = 1.0;

    if (_entry.value < 1) {
      final start = math.min(i * 0.07, 0.5);
      final t = Interval(
        start,
        math.min(start + 0.45, 1.0),
        curve: Curves.easeOutBack,
      ).transform(_entry.value);
      top += (1 - t) * 160;
      opacity = t;
    }
    if (c.id == _dropping) {
      top -= (1 - Curves.elasticOut.transform(_drop.value)) * 180;
      opacity *= _drop.value * 4;
    }
    if (c.id == _removing) {
      final t = Curves.easeInCubic.transform(_remove.value);
      dx = -t * (width + 40);
      angle = -0.12 * t;
      opacity *= 1 - t;
    }

    return AnimatedPositioned(
      key: ValueKey(c.id),
      // Folders shuffle smoothly to make room while one is dragged; at any
      // other time they follow the scroll exactly.
      duration: _dragFrom != null && !dragging
          ? const Duration(milliseconds: 220)
          : Duration.zero,
      curve: Curves.easeOutCubic,
      left: _side,
      top: top,
      width: width,
      height: _folderHeight,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.rotate(
            angle: angle,
            child: RepaintBoundary(
              child: _FolderTile(
                collection: c,
                index: i,
                noteCount: widget.noteCount(c),
                lifted: dragging,
                onTap: () => widget.onOpen(c),
                onMore: () => widget.onMore(c),
                onDragStart: (d) => _startDrag(i, d),
                onDragUpdate: _updateDrag,
                onDragEnd: _endDrag,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FolderTile extends StatefulWidget {
  const _FolderTile({
    required this.collection,
    required this.index,
    required this.noteCount,
    required this.lifted,
    required this.onTap,
    required this.onMore,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final Collection collection;
  final int index;
  final int noteCount;
  final bool lifted;
  final VoidCallback onTap;
  final VoidCallback onMore;
  final ValueChanged<LongPressStartDetails> onDragStart;
  final ValueChanged<LongPressMoveUpdateDetails> onDragUpdate;
  final VoidCallback onDragEnd;

  @override
  State<_FolderTile> createState() => _FolderTileState();
}

class _FolderTileState extends State<_FolderTile> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.collection;
    final text = Theme.of(context).textTheme;
    final ink = Theme.of(context).colorScheme.outline;
    final cover = coverColor(c.cover);
    // The back and tab are lighter than the front, like a folder's inside.
    final back = Color.lerp(cover, AppColors.paperLight, 0.45)!;
    final raised = _pressed || widget.lifted;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final lift = raised && !reduce ? -8.0 : 0.0;
    final papers = math.min(widget.noteCount, 3);

    return Semantics(
      button: true,
      label: '${c.name}, ${noteCountLabel(widget.noteCount)}',
      hint: 'Long-press and drag to reorder',
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        onLongPressStart: (d) {
          _setPressed(false);
          widget.onDragStart(d);
        },
        onLongPressMoveUpdate: widget.onDragUpdate,
        onLongPressEnd: (_) => widget.onDragEnd(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, lift, 0),
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth;
              final tabWidth = math.min(w * 0.46, 200.0);
              final tabLeft = switch (widget.index % 3) {
                0 => 12.0,
                1 => (w - tabWidth) / 2,
                _ => w - tabWidth - 12,
              };
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _FolderBackPainter(
                        color: back,
                        ink: ink,
                        tabLeft: tabLeft,
                        tabWidth: tabWidth,
                        raised: raised,
                      ),
                    ),
                  ),
                  Positioned(
                    left: tabLeft + 14,
                    width: tabWidth - 28,
                    top: 5,
                    height: _tabHeight - 6,
                    child: Hero(
                      tag: folderTabHeroTag(c.id),
                      child: Material(
                        type: MaterialType.transparency,
                        child: Text(
                          c.name,
                          style: text.titleMedium?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  // A sheet per note (up to three) peeking out of the folder.
                  for (var k = 0; k < papers; k++)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOut,
                      left: 18.0 + k * 14,
                      right: 26.0 + (papers - 1 - k) * 10,
                      top: _tabHeight + 4 + k * 5 - (raised && !reduce ? 6 : 0),
                      height: 90,
                      child: _Paper(seed: c.id.hashCode + k),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: _frontTop,
                    bottom: 0,
                    child: Hero(
                      tag: folderHeroTag(c.id),
                      child: FolderFront(
                        color: cover,
                        seed: c.id.hashCode,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FolderSticker(noteCountLabel(widget.noteCount)),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Folder options',
                              color: AppColors.ink,
                              icon: const Icon(Icons.more_horiz_rounded),
                              onPressed: widget.onMore,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A folder's front panel in its cover color. The drawer and the collection
/// page header share it as a hero, so the folder flies between them.
class FolderFront extends StatelessWidget {
  const FolderFront({
    super.key,
    required this.color,
    required this.seed,
    required this.child,
  });

  final Color color;
  final int seed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: SketchBorder(
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline,
          width: SketchStyles.strokeWidth,
        ),
        radius: 10,
        seed: seed,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    );
  }
}

/// A small paper label stuck on a folder front.
class FolderSticker extends StatelessWidget {
  const FolderSticker(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: AppColors.paperLight,
          shape: SketchBorder(
            radius: 5,
            seed: label.hashCode,
            passes: 1,
            side: const BorderSide(color: AppColors.ink, width: 1.1),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: AppColors.ink, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

/// A sheet of ruled paper.
class _Paper extends StatelessWidget {
  const _Paper({required this.seed});

  final int seed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: AppColors.paperLight,
        shape: SketchBorder(
          radius: 3,
          seed: seed,
          passes: 1,
          side: BorderSide(
            color: AppColors.ink.withValues(alpha: 0.55),
            width: 1,
          ),
        ),
      ),
      child: const CustomPaint(
        painter: RuledPaperPainter(spacing: 7, showMargin: false),
      ),
    );
  }
}

/// The folder's back panel with its tab, outlined twice like a pencil line.
class _FolderBackPainter extends CustomPainter {
  const _FolderBackPainter({
    required this.color,
    required this.ink,
    required this.tabLeft,
    required this.tabWidth,
    required this.raised,
  });

  final Color color;
  final Color ink;
  final double tabLeft;
  final double tabWidth;
  final bool raised;

  Path _path(Size size) {
    const r = 10.0, t = _tabHeight;
    final w = size.width, h = size.height;
    final l = tabLeft, right = tabLeft + tabWidth;
    return Path()
      ..moveTo(0, h)
      ..lineTo(0, t + r)
      ..quadraticBezierTo(0, t, r, t)
      ..lineTo(l, t)
      ..lineTo(l + 8, 5)
      ..quadraticBezierTo(l + 10, 0, l + 17, 0)
      ..lineTo(right - 17, 0)
      ..quadraticBezierTo(right - 10, 0, right - 8, 5)
      ..lineTo(right, t)
      ..lineTo(w - r, t)
      ..quadraticBezierTo(w, t, w, t + r)
      ..lineTo(w, h)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _path(size);
    canvas
      ..drawShadow(path, Colors.black, raised ? 10 : 3, false)
      ..drawPath(path, Paint()..color = color);
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = SketchStyles.strokeWidth
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..drawPath(path, line)
      ..drawPath(
        path.shift(const Offset(0.7, 0.5)),
        line
          ..color = ink.withValues(alpha: 0.4)
          ..strokeWidth = 0.9,
      );
  }

  @override
  bool shouldRepaint(_FolderBackPainter old) =>
      old.color != color ||
      old.ink != ink ||
      old.tabLeft != tabLeft ||
      old.tabWidth != tabWidth ||
      old.raised != raised;
}

/// The drawer's front edge with its pull handle, in front of the folders.
class _DrawerFront extends StatelessWidget {
  const _DrawerFront();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: Color.alphaBlend(
          scheme.outline.withValues(alpha: 0.06),
          scheme.surfaceContainerHighest,
        ),
        shape: SketchBorder(
          side: BorderSide(color: scheme.outline, width: 1.8),
          radius: 8,
          seed: 41,
        ),
        child: SizedBox(
          height: _lipHeight,
          child: Center(
            child: Container(
              width: 92,
              height: 12,
              decoration: BoxDecoration(
                color: scheme.outline.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
