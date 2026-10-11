import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/sketch_styles.dart';
import '../domain/note.dart';

/// A note's to-do list: tick items off, edit them in place, press Enter
/// for the next one, or remove them.
class ChecklistEditor extends StatefulWidget {
  const ChecklistEditor({
    super.key,
    required this.items,
    required this.onChanged,
  });

  final List<ChecklistItem> items;
  final ValueChanged<List<ChecklistItem>> onChanged;

  @override
  State<ChecklistEditor> createState() => _ChecklistEditorState();
}

class _ChecklistEditorState extends State<ChecklistEditor> {
  final _controllers = <String, TextEditingController>{};
  final _focusNodes = <String, FocusNode>{};

  /// The item to focus once the list has rebuilt with it.
  String? _focusNext;

  /// The latest items, updated as soon as anything changes. Edits build on
  /// this rather than on [ChecklistEditor.items], which only catches up on
  /// the next rebuild: a keyboard can deliver text and Enter in one frame,
  /// and the Enter must not undo the text.
  late List<ChecklistItem> _items = widget.items;

  @override
  void initState() {
    super.initState();
    // A brand-new checklist starts ready to type into.
    final items = widget.items;
    if (items.length == 1 && items.first.text.isEmpty) {
      _focusNext = items.first.id;
    }
  }

  @override
  void didUpdateWidget(ChecklistEditor old) {
    super.didUpdateWidget(old);
    _items = widget.items;
    final ids = {for (final i in widget.items) i.id};
    final gone = [..._controllers.keys.where((id) => !ids.contains(id))];
    for (final id in gone) {
      final controller = _controllers.remove(id);
      final node = _focusNodes.remove(id);
      // Disposed after this frame, once their fields have left the tree.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller?.dispose();
        node?.dispose();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final n in _focusNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  TextEditingController _controller(ChecklistItem item) => _controllers
      .putIfAbsent(item.id, () => TextEditingController(text: item.text));

  FocusNode _node(String id) => _focusNodes.putIfAbsent(id, FocusNode.new);

  void _set(List<ChecklistItem> items) {
    _items = items;
    widget.onChanged(items);
  }

  /// Applies [change] to the current version of item [id].
  void _change(String id, ChecklistItem Function(ChecklistItem) change) =>
      _set([for (final i in _items) i.id == id ? change(i) : i]);

  void _insertAfter(String id) {
    final item = ChecklistItem.create();
    final index = _items.indexWhere((i) => i.id == id);
    _focusNext = item.id;
    _set([..._items]..insert(index + 1, item));
  }

  void _remove(String id) {
    final index = _items.indexWhere((i) => i.id == id);
    if (index == -1) return;
    final items = [..._items]..removeAt(index);
    if (items.isNotEmpty) _focusNext = items[math.max(0, index - 1)].id;
    _set(items);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final pending = _focusNext;
    if (pending != null) {
      _focusNext = null;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _focusNodes[pending]?.requestFocus(),
      );
    }
    final done = _items.where((i) => i.done).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Checklist',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            Semantics(
              liveRegion: true,
              child: Text(
                '$done/${_items.length} done',
                style: text.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        for (final item in _items)
          Row(
            key: ValueKey(item.id),
            children: [
              Checkbox(
                value: item.done,
                semanticLabel: item.text.isEmpty ? 'Item' : item.text,
                onChanged: (v) =>
                    _change(item.id, (i) => i.copyWith(done: v ?? false)),
              ),
              Expanded(
                // Ticking draws a pencil line through the item and greys
                // it out; unticking rubs the line out a little faster.
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: item.done ? 1 : 0),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : Duration(milliseconds: item.done ? 180 : 120),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, _) {
                    final style = text.bodyLarge?.copyWith(
                      color: Color.lerp(
                        scheme.onSurface,
                        scheme.onSurfaceVariant,
                        t,
                      ),
                    );
                    return CustomPaint(
                      foregroundPainter: _PencilStrike(
                        progress: t,
                        text: item.text,
                        style: style,
                        color: scheme.onSurfaceVariant,
                        seed: item.id.hashCode,
                      ),
                      child: TextField(
                        controller: _controller(item),
                        focusNode: _node(item.id),
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.next,
                        style: style,
                        decoration: pageInput('List item'),
                        onChanged: (v) =>
                            _change(item.id, (i) => i.copyWith(text: v)),
                        onSubmitted: (_) => _insertAfter(item.id),
                      ),
                    );
                  },
                ),
              ),
              IconButton(
                tooltip: 'Remove item',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () => _remove(item.id),
              ),
            ],
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _insertAfter(_items.last.id),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add item'),
          ),
        ),
      ],
    );
  }
}

/// A slightly wobbly pencil line through an item's text, drawn left to
/// right as [progress] goes from 0 to 1.
class _PencilStrike extends CustomPainter {
  const _PencilStrike({
    required this.progress,
    required this.text,
    required this.style,
    required this.color,
    required this.seed,
  });

  final double progress;
  final String text;
  final TextStyle? style;
  final Color color;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || text.isEmpty) return;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: size.width);
    final width = (painter.width + 4).clamp(0.0, size.width) * progress;
    painter.dispose();
    final y = size.height / 2 + 1;
    final wobble = ((seed % 7) - 3) * 0.35;
    canvas.drawPath(
      Path()
        ..moveTo(-2, y + wobble)
        ..quadraticBezierTo(width / 2, y - wobble - 1, width, y + wobble / 2),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_PencilStrike old) =>
      old.progress != progress ||
      old.text != text ||
      old.style != style ||
      old.color != color;
}
