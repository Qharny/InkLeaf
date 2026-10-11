import 'package:flutter/material.dart';

import '../../../core/widgets/doodles.dart';
import '../data/notes_repository.dart';
import '../domain/note.dart';
import 'bin_animation.dart';
import 'note_card.dart';

/// Trashed notes: restore them or delete them for good.
class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  Future<void> _confirmEmpty(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Empty the trash?'),
        content: const Text('These notes will be deleted for good.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Empty trash'),
          ),
        ],
      ),
    );
    if (!(ok ?? false) || !context.mounted) return;
    // One crumpled page from the middle of the list stands in for them all.
    final list = globalRectOf(context);
    if (list != null) {
      throwInBin(
        context,
        from: Rect.fromCenter(center: list.center, width: 200, height: 150),
        paper: noteFill(context, 0),
      );
    }
    NotesRepository.instance.emptyTrash();
  }

  /// [context] should be the note's card, which "Delete forever" throws
  /// into the bin.
  void _showActions(BuildContext context, Note note) {
    final repo = NotesRepository.instance;
    final card = globalRectOf(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.restore_rounded),
              title: const Text('Restore'),
              onTap: () {
                repo.restore(note.id);
                Navigator.of(sheetContext).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined),
              title: const Text('Delete forever'),
              onTap: () {
                if (card != null) {
                  throwInBin(
                    context,
                    from: card,
                    paper: noteFill(context, note.color),
                  );
                }
                repo.delete(note.id);
                Navigator.of(sheetContext).pop();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = NotesRepository.instance;
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final trashed = repo.trashed;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Trash'),
            actions: [
              if (trashed.isNotEmpty)
                TextButton(
                  onPressed: () => _confirmEmpty(context),
                  child: const Text('Empty'),
                ),
            ],
          ),
          body: trashed.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SquiggleDoodle(width: 90),
                      const SizedBox(height: 16),
                      Text('The trash is empty', style: text.headlineSmall),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: trashed.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => Builder(
                    builder: (context) => NoteCard(
                      note: trashed[i],
                      fixedHeight: false,
                      previewLines: 2,
                      onTap: () => _showActions(context, trashed[i]),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
