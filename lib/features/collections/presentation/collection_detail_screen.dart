import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/sketch_styles.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/domain/note.dart';
import '../../notes/presentation/note_card.dart';
import '../data/collections_repository.dart';
import '../domain/collection.dart';
import 'collection_widgets.dart';
import 'collections_screen.dart';
import 'folder_drawer.dart';

/// One collection: its description and notes, with ways to add existing
/// notes, write a new one into it, or take notes out.
class CollectionDetailScreen extends StatelessWidget {
  const CollectionDetailScreen({super.key, required this.collectionId});

  final String collectionId;

  void _writeNote(BuildContext context) =>
      context.push(AppRoutes.newNoteIn(collectionId));

  void _pickNotes(BuildContext context, Collection collection) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => _NotePickerSheet(
        collection: collection,
        onWriteNote: () => _writeNote(context),
      ),
    );
  }

  void _noteActions(BuildContext context, Collection collection, Note note) {
    final repo = CollectionsRepository.instance;
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                note.displayTitle,
                style: Theme.of(sheetContext).textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_remove_outlined),
              title: Text('Remove from ${collection.name}'),
              subtitle: const Text('The note itself is kept'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                repo.removeNote(collection.id, note.id);
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: const Text('Removed from collection'),
                      action: SnackBarAction(
                        label: 'Undo',
                        onPressed: () => repo.addNote(collection.id, note.id),
                      ),
                    ),
                  );
              },
            ),
            ListTile(
              leading: const Icon(Icons.collections_bookmark_outlined),
              title: const Text('Collections…'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showCollectionPicker(context, note.id);
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
    final repo = CollectionsRepository.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([repo, NotesRepository.instance]),
      builder: (context, _) {
        final collection = repo.byId(collectionId);
        if (collection == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Text(
                'This collection no longer exists.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          );
        }
        final notes = liveNotesIn(collection);

        return Scaffold(
          appBar: AppBar(
            title: Hero(
              tag: folderTabHeroTag(collection.id),
              child: Material(
                type: MaterialType.transparency,
                child: Text(collection.name, overflow: TextOverflow.ellipsis),
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Add notes',
                icon: const Icon(Icons.playlist_add_rounded),
                onPressed: () => _pickNotes(context, collection),
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (action) {
                  if (action == 'edit') {
                    editCollection(context, collection);
                  } else {
                    final messenger = ScaffoldMessenger.of(context);
                    context.pop();
                    deleteCollection(messenger, collection);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit collection'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline_rounded),
                      title: Text('Delete collection'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Header(
                  collection: collection,
                  count: notes.length,
                  onWriteNote: () => _writeNote(context),
                ),
              ),
              if (notes.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyCollection(
                    onAdd: () => _pickNotes(context, collection),
                    onWrite: () => _writeNote(context),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  sliver: SliverList.separated(
                    itemCount: notes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _SlideOut(
                      index: i,
                      child: NoteCard(
                        note: notes[i],
                        fixedHeight: false,
                        previewLines: 2,
                        onTap: () =>
                            context.push(AppRoutes.noteById(notes[i].id)),
                        onLongPress: () =>
                            _noteActions(context, collection, notes[i]),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The folder's front panel: it flies here from the drawer (as a hero) and
/// carries the note count, description and a New note button.
class _Header extends StatelessWidget {
  const _Header({
    required this.collection,
    required this.count,
    required this.onWriteNote,
  });

  final Collection collection;
  final int count;
  final VoidCallback onWriteNote;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Hero(
        tag: folderHeroTag(collection.id),
        child: FolderFront(
          color: coverColor(collection.cover),
          seed: collection.id.hashCode,
          child: Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FolderSticker(noteCountLabel(count)),
                    const Spacer(),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.ink,
                        backgroundColor: AppColors.paperLight,
                      ),
                      onPressed: onWriteNote,
                      icon: const Icon(Icons.edit_note_rounded),
                      label: const Text('New note'),
                    ),
                  ],
                ),
                if (collection.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  DecoratedBox(
                    decoration: ShapeDecoration(
                      color: AppColors.paperLight,
                      shape: SketchBorder(
                        radius: 5,
                        seed: collection.id.hashCode + 2,
                        passes: 1,
                        side: const BorderSide(
                          color: AppColors.ink,
                          width: 1.1,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        collection.description,
                        style: text.bodyLarge?.copyWith(color: AppColors.ink),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Notes slide out of the folder one after another when the page opens.
class _SlideOut extends StatelessWidget {
  const _SlideOut({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduce
          ? Duration.zero
          : Duration(milliseconds: 280 + 60 * index.clamp(0, 8)),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * -28),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _EmptyCollection extends StatelessWidget {
  const _EmptyCollection({required this.onAdd, required this.onWrite});

  final VoidCallback onAdd;
  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 96),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'This notebook is empty',
            style: text.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Add notes you already have, or start a new one here.',
            style: text.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.playlist_add_rounded),
            label: const Text('Add existing notes'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onWrite,
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Write a new note'),
          ),
        ],
      ),
    );
  }
}

/// Checklist of every note; ticked notes are in the collection.
class _NotePickerSheet extends StatefulWidget {
  const _NotePickerSheet({required this.collection, required this.onWriteNote});

  final Collection collection;
  final VoidCallback onWriteNote;

  @override
  State<_NotePickerSheet> createState() => _NotePickerSheetState();
}

class _NotePickerSheetState extends State<_NotePickerSheet> {
  final _notes = NotesRepository.instance.notes;
  late final Set<String> _selected = {...widget.collection.noteIds};
  String _query = '';

  void _done() {
    // Trashed notes aren't listed but stay selected, so restoring one
    // brings it back to this collection.
    CollectionsRepository.instance.setNotes(widget.collection.id, _selected);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final shown = _notes.where((n) => n.matches(_query)).toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  'Notes in ${widget.collection.name}',
                  style: text.titleLarge,
                ),
              ),
              if (_notes.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                  child: Text('You have no notes yet.', style: text.bodyLarge),
                )
              else ...[
                if (_notes.length > 6)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      decoration: const InputDecoration(
                        hintText: 'Filter notes',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: shown.length,
                    itemBuilder: (context, i) {
                      final note = shown[i];
                      return CheckboxListTile(
                        value: _selected.contains(note.id),
                        onChanged: (on) => setState(
                          () => on!
                              ? _selected.add(note.id)
                              : _selected.remove(note.id),
                        ),
                        secondary: CircleAvatar(
                          radius: 10,
                          backgroundColor: noteFill(context, note.color),
                        ),
                        title: Text(
                          note.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: note.preview.isEmpty
                            ? null
                            : Text(
                                note.preview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                      );
                    },
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onWriteNote();
                      },
                      icon: const Icon(Icons.edit_note_rounded),
                      label: const Text('Write new'),
                    ),
                    const Spacer(),
                    FilledButton(onPressed: _done, child: const Text('Done')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
