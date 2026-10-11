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
import '../data/notes_repository.dart';
import '../domain/note.dart';
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

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final _repo = NotesRepository.instance;
  late Note _note;
  late final TextEditingController _title;
  late final TextEditingController _body;
  bool _missing = false;

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
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  /// Applies [next]; [edited] bumps the "last edited" time.
  void _update(Note next, {bool edited = false}) {
    setState(() {
      _note = edited ? next.copyWith(updatedAt: DateTime.now()) : next;
    });
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
    if (!_note.isEmpty) return;
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
    if (_repo.byId(_note.id) != null && !_note.isEmpty) {
      moveNoteToTrash(messenger, _note);
    }
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
              tooltip: 'Color',
              icon: const Icon(Icons.palette_outlined),
              onPressed: _pickColor,
            ),
            IconButton(
              tooltip: 'Sketch',
              icon: const Icon(Icons.draw_outlined),
              onPressed: _editSketch,
            ),
            IconButton(
              tooltip: 'Collections',
              icon: const Icon(Icons.collections_bookmark_outlined),
              onPressed: () => showCollectionPicker(context, _note.id),
            ),
            IconButton(
              tooltip: 'Move to trash',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _trash,
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
              onChanged: (v) => _update(_note.copyWith(title: v), edited: true),
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
              onChanged: (v) => _update(_note.copyWith(body: v), edited: true),
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
