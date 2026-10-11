import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/sketch_styles.dart';
import '../../canvas/domain/board.dart';
import '../../canvas/presentation/board_painters.dart';
import '../../../core/storage/media_store.dart';
import '../../../core/utils/relative_time.dart';
import '../../collections/data/collections_repository.dart';
import '../../collections/presentation/collection_widgets.dart';
import '../../home/presentation/home_screen.dart';
import '../../reminders/data/reminders.dart';
import '../../reminders/presentation/reminder_picker.dart';
import '../data/notes_repository.dart';
import '../domain/note.dart';
import 'bin_animation.dart';
import 'checklist_editor.dart';
import 'note_card.dart';
import 'scan_preview.dart';
import 'voice_note_player.dart';

/// Writes a new note, or edits the note with [noteId].
///
/// Changes save as you type. A note left empty is discarded on close.
class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, this.noteId, this.collectionId});

  final String? noteId;

  /// For a new note: the collection to file it in once it has content.
  final String? collectionId;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen>
    with WidgetsBindingObserver {
  final _repo = NotesRepository.instance;

  /// Typing is saved once the writer pauses, rather than on every key: each
  /// save redraws every list showing notes.
  static const _typingPause = Duration(milliseconds: 350);
  Timer? _saveTimer;
  late Note _note;
  late final TextEditingController _title;
  late final TextEditingController _body;
  bool _missing = false;

  /// The reminder set in this visit, so only that one rings its bell.
  DateTime? _justSet;

  /// Whether the new note has been added to [NoteEditorScreen.collectionId].
  bool _filed = false;

  bool get _isNew => widget.noteId == null;

  @override
  void initState() {
    super.initState();
    final existing = _isNew ? null : _repo.byId(widget.noteId!);
    _missing = !_isNew && existing == null;
    // New notes cycle through the pastels so the desk stays colorful.
    _note = existing ?? Note.create(color: _repo.notes.length % 5);
    _title = TextEditingController(text: _note.title);
    _body = TextEditingController(text: _note.body);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Closed some way other than popping: save what's left once this frame
    // is done (lists can't rebuild while the tree is being torn down).
    if (_saveTimer?.isActive ?? false) {
      _saveTimer!.cancel();
      final pending = _note;
      if (!pending.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _repo.save(pending),
        );
      }
    }
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Never lose a pause's worth of typing to the app being closed.
    if (state != AppLifecycleState.resumed) _save();
  }

  /// Applies [next]; [edited] bumps the "last edited" time. While [typing]
  /// the save waits for a pause; anything else is saved straight away.
  void _update(Note next, {bool edited = false, bool typing = false}) {
    setState(() {
      _note = edited ? next.copyWith(updatedAt: DateTime.now()) : next;
    });
    _saveTimer?.cancel();
    if (typing) {
      _saveTimer = Timer(_typingPause, _save);
    } else {
      _save();
    }
  }

  void _save() {
    _saveTimer?.cancel();
    _saveTimer = null;
    // Empty notes are not saved; one emptied while editing is removed on
    // close instead, so it doesn't flicker off the desk mid-sentence.
    if (_note.isEmpty) return;
    _repo.save(_note);
    final collectionId = widget.collectionId;
    if (collectionId != null && !_filed) {
      _filed = true;
      CollectionsRepository.instance.addNote(collectionId, _note.id);
    }
  }

  void _onClosed() {
    _save();
    if (!_note.isEmpty) {
      // The notification shows the note's title, which may have changed.
      Reminders.instance.refresh(_note.id);
      return;
    }
    if (_repo.byId(_note.id) != null) _repo.delete(_note.id);
    CollectionsRepository.instance.setMembership(_note.id, const {});
  }

  Future<void> _addTag() async {
    var value = '';
    final tag = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add a tag'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. ideas',
            prefixText: '#',
          ),
          onChanged: (v) => value = v,
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(value),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    final clean = tag
        ?.trim()
        .toLowerCase()
        .replaceAll(RegExp(r'^#+'), '')
        .replaceAll(RegExp(r'\s+'), '-');
    if (clean == null || clean.isEmpty || _note.tags.contains(clean)) return;
    _update(_note.copyWith(tags: [..._note.tags, clean]), edited: true);
  }

  Future<void> _removeRecording(NoteAudio audio) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this recording?'),
        content: const Text('The audio is deleted for good.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (!(ok ?? false) || !mounted) return;
    MediaStore.audio.delete(audio.fileName);
    _update(_note.copyWith(audio: () => null), edited: true);
  }

  Future<void> _removeScan(String fileName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove the scanned photo?'),
        content: const Text('The text stays; the photo is deleted for good.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (!(ok ?? false) || !mounted) return;
    MediaStore.scans.delete(fileName);
    _update(_note.copyWith(scanFile: () => null), edited: true);
  }

  Future<void> _setReminder() async {
    final choice = await showReminderPicker(context, current: _note.remindAt);
    if (choice == null || !mounted) return;
    final at = choice.at;
    _justSet = at;
    _update(_note.copyWith(remindAt: () => at));
    if (at == null) return;
    final allowed = await Reminders.instance.requestPermission();
    if (!allowed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          persist: false,
          duration: Duration(seconds: 3),
          content: Text(
            "Notifications are off for Inkleaf, so this reminder can't "
            "alert you. You can turn them on in your phone's settings.",
          ),
        ),
      );
    }
  }

  Future<void> _editSketch() async {
    final strokes = await context.push<List<BoardStroke>>(
      AppRoutes.sketchFor(_note.id),
      extra: _note.sketch,
    );
    if (strokes == null || !mounted || identical(strokes, _note.sketch)) {
      return;
    }
    _update(_note.copyWith(sketch: strokes), edited: true);
  }

  void _pickColor() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          child: NoteColorPicker(
            selected: _note.color,
            onSelected: (color) {
              _update(_note.copyWith(color: color));
              Navigator.of(sheetContext).pop();
            },
          ),
        ),
      ),
    );
  }

  void _trash() {
    final messenger = ScaffoldMessenger.of(context);
    _save();
    if (_repo.byId(_note.id) != null && !_note.isEmpty) {
      // The page itself folds up and goes in the bin.
      final page = globalRectOf(context);
      if (page != null) {
        throwInBin(
          context,
          from: page.deflate(32),
          paper: noteFill(context, _note.color),
        );
      }
      moveNoteToTrash(messenger, _note);
    }
    context.pop();
  }

  /// Saves and closes, dismissing the keyboard.
  void _done() {
    FocusScope.of(context).unfocus();
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    if (_missing) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text('This note no longer exists.', style: text.bodyLarge),
        ),
      );
    }

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _onClosed();
      },
      child: Scaffold(
        backgroundColor: noteFill(context, _note.color),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          actions: [
            IconButton(
              tooltip: _note.pinned ? 'Unpin' : 'Pin',
              isSelected: _note.pinned,
              icon: const Icon(Icons.push_pin_outlined),
              selectedIcon: const Icon(Icons.push_pin_rounded),
              onPressed: () => _update(_note.copyWith(pinned: !_note.pinned)),
            ),
            IconButton(
              tooltip: 'Sketch',
              icon: const Icon(Icons.draw_outlined),
              onPressed: _editSketch,
            ),
            PopupMenuButton<VoidCallback>(
              tooltip: 'More',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (action) => action(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: _pickColor,
                  child: const ListTile(
                    leading: Icon(Icons.palette_outlined),
                    title: Text('Color'),
                  ),
                ),
                PopupMenuItem(
                  value: () => showCollectionPicker(context, _note.id),
                  child: const ListTile(
                    leading: Icon(Icons.collections_bookmark_outlined),
                    title: Text('Collections'),
                  ),
                ),
                PopupMenuItem(
                  value: _trash,
                  child: const ListTile(
                    leading: Icon(Icons.delete_outline_rounded),
                    title: Text('Move to trash'),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(onPressed: _done, child: const Text('Done')),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          children: [
            TextField(
              controller: _title,
              autofocus: _isNew,
              style: text.headlineMedium,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              maxLines: null,
              decoration: const InputDecoration.collapsed(hintText: 'Title'),
              onChanged: (v) =>
                  _update(_note.copyWith(title: v), edited: true, typing: true),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final tag in _note.tags)
                  InputChip(
                    label: Text('#$tag'),
                    deleteButtonTooltipMessage: 'Remove #$tag',
                    onDeleted: () => _update(
                      _note.copyWith(tags: [..._note.tags]..remove(tag)),
                      edited: true,
                    ),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Tag'),
                  onPressed: _addTag,
                ),
                if (_note.remindAt case final at?)
                  InputChip(
                    avatar: _RingingBell(at: at, ringNow: at == _justSet),
                    label: Text(reminderLabel(context, at)),
                    tooltip: 'Change reminder',
                    onPressed: _setReminder,
                    deleteButtonTooltipMessage: 'Remove reminder',
                    onDeleted: () =>
                        _update(_note.copyWith(remindAt: () => null)),
                  )
                else
                  ActionChip(
                    avatar: const Icon(
                      Icons.notifications_none_rounded,
                      size: 18,
                    ),
                    label: const Text('Remind me'),
                    onPressed: _setReminder,
                  ),
                if (_note.checklist.isEmpty)
                  ActionChip(
                    avatar: const Icon(Icons.checklist_rounded, size: 18),
                    label: const Text('Checklist'),
                    onPressed: () => _update(
                      _note.copyWith(checklist: [ChecklistItem.create()]),
                      edited: true,
                    ),
                  ),
              ],
            ),
            if (_note.scanFile case final scan?)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ScanPreview(
                  key: ValueKey(scan),
                  fileName: scan,
                  onRemove: () => _removeScan(scan),
                ),
              ),
            if (_note.audio case final audio?)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: VoiceNotePlayer(
                  key: ValueKey(audio.fileName),
                  audio: audio,
                  onRemove: () => _removeRecording(audio),
                ),
              ),
            if (_note.sketch.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(
                  button: true,
                  label: 'Sketch. Tap to edit',
                  child: Material(
                    color: scheme.surfaceContainerLowest.withValues(alpha: 0.5),
                    shape: SketchBorder(
                      side: BorderSide(color: scheme.outline, width: 1.2),
                      seed: _note.id.hashCode + 1,
                      passes: 1,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _editSketch,
                      child: SizedBox(
                        height: 220,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: SketchPainter(
                            strokes: _note.sketch,
                            ink: scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            SketchDivider(seed: _note.id.hashCode, color: scheme.outline),
            if (_note.checklist.isNotEmpty) ...[
              ChecklistEditor(
                items: _note.checklist,
                onChanged: (items) => _update(
                  _note.copyWith(checklist: items),
                  edited: true,
                  typing: true,
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _body,
              style: text.bodyLarge?.copyWith(height: 1.5),
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              maxLines: null,
              minLines: 12,
              decoration: const InputDecoration.collapsed(
                hintText: 'Start writing…',
              ),
              onChanged: (v) =>
                  _update(_note.copyWith(body: v), edited: true, typing: true),
            ),
            const SizedBox(height: 24),
            Text(
              'Last edited: ${relativeTime(_note.updatedAt)}',
              style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// The reminder chip's bell: it swings twice, smaller each time, when a
/// reminder is set or moved, to confirm it took.
class _RingingBell extends StatefulWidget {
  const _RingingBell({required this.at, required this.ringNow});

  final DateTime at;

  /// Rings on appearing: the reminder was just set, not merely opened.
  final bool ringNow;

  @override
  State<_RingingBell> createState() => _RingingBellState();
}

class _RingingBellState extends State<_RingingBell>
    with SingleTickerProviderStateMixin {
  late final _ring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  bool get _upcoming => widget.at.isAfter(DateTime.now());

  @override
  void initState() {
    super.initState();
    // A chip that appears because a reminder was just set rings too.
    if (widget.ringNow) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRing());
    }
  }

  @override
  void didUpdateWidget(_RingingBell old) {
    super.didUpdateWidget(old);
    if (old.at != widget.at && widget.ringNow) _maybeRing();
  }

  void _maybeRing() {
    if (!mounted || !_upcoming) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    _ring.forward(from: 0);
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ring,
      builder: (context, child) {
        final t = _ring.value;
        return Transform.rotate(
          alignment: Alignment.topCenter,
          angle: math.sin(t * math.pi * 4) * 0.22 * (1 - t),
          child: child,
        );
      },
      child: Icon(
        _upcoming
            ? Icons.notifications_active_outlined
            : Icons.notifications_none_rounded,
        size: 18,
      ),
    );
  }
}
