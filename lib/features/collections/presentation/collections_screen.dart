import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_shell.dart';
import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/sketch_styles.dart';
import '../../../core/widgets/doodles.dart';
import '../../notes/data/notes_repository.dart';
import '../data/collections_repository.dart';
import '../domain/collection.dart';
import 'collection_widgets.dart';
import 'folder_drawer.dart';

/// The Collections tab: every collection as a folder in an open drawer.
class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  final _drawer = GlobalKey<FolderDrawerState>();

  Future<void> _create(BuildContext context) async {
    final details = await showCollectionForm(context);
    if (details == null || !context.mounted) return;
    final collection = Collection.create(
      name: details.name,
      description: details.description,
      cover: details.cover,
    );
    CollectionsRepository.instance.save(collection);
    // Once the new folder is in the drawer, drop it in from above.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _drawer.currentState?.dropIn(collection.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = CollectionsRepository.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collections'),
        actions: [
          IconButton(
            tooltip: 'New collection',
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () => _create(context),
          ),
          const SecondaryMenuButton(),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([repo, NotesRepository.instance]),
        builder: (context, _) {
          final collections = repo.collections;
          if (collections.isEmpty) {
            return _EmptyDrawer(onCreate: () => _create(context));
          }
          return FolderDrawer(
            key: _drawer,
            collections: collections,
            noteCount: (c) => liveNotesIn(c).length,
            onOpen: (c) => context.go(AppRoutes.collectionById(c.id)),
            onMore: (c) => _showActions(context, c),
            onReorder: repo.reorder,
          );
        },
      ),
    );
  }

  void _showActions(BuildContext context, Collection collection) {
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
                collection.name,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                editCollection(context, collection);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Delete collection'),
              subtitle: const Text('Its notes are kept'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                final drawer = _drawer.currentState;
                if (drawer == null) {
                  deleteCollection(messenger, collection);
                } else {
                  drawer.removeAnimated(
                    collection.id,
                    () => deleteCollection(messenger, collection),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Opens the edit form for [collection] and saves any changes.
Future<void> editCollection(BuildContext context, Collection collection) async {
  final details = await showCollectionForm(context, existing: collection);
  if (details == null) return;
  final repo = CollectionsRepository.instance;
  final current = repo.byId(collection.id);
  if (current == null) return;
  repo.save(
    current.copyWith(
      name: details.name,
      description: details.description,
      cover: details.cover,
      updatedAt: DateTime.now(),
    ),
  );
}

/// Deletes [collection] (never its notes) and offers to undo.
void deleteCollection(ScaffoldMessengerState messenger, Collection collection) {
  final repo = CollectionsRepository.instance;
  repo.delete(collection.id);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('Deleted “${collection.name}”'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => repo.save(collection),
        ),
      ),
    );
}

class _EmptyDrawer extends StatelessWidget {
  const _EmptyDrawer({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 96),
        child: Column(
          children: [
            const Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.folder_copy_outlined, size: 64),
                Positioned(
                  right: -26,
                  top: -14,
                  child: LeafDoodle(size: 30, rotation: 0.6),
                ),
              ],
            ),
            const SizedBox(height: 20),
            MarkerHighlight(
              color: AppColors.markerPurple,
              child: Text('An empty drawer', style: text.headlineSmall),
            ),
            const SizedBox(height: 8),
            Text(
              'File related notes into folders: recipes, a trip, a class. '
              'A note can live in more than one.',
              style: text.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New collection'),
            ),
          ],
        ),
      ),
    );
  }
}
