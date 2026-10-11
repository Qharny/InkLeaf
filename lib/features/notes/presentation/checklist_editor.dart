import 'dart:math' as math;

import 'package:flutter/material.dart';

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
                child: TextField(
                  controller: _controller(item),
                  focusNode: _node(item.id),
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  style: text.bodyLarge?.copyWith(
                    decoration: item.done ? TextDecoration.lineThrough : null,
                    color: item.done ? scheme.onSurfaceVariant : null,
                  ),
                  decoration: const InputDecoration.collapsed(
                    hintText: 'List item',
                  ),
                  onChanged: (v) =>
                      _change(item.id, (i) => i.copyWith(text: v)),
                  onSubmitted: (_) => _insertAfter(item.id),
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
