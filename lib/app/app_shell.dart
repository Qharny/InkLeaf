import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/notes/presentation/note_templates.dart';
import 'router.dart';
import 'theme/sketch_styles.dart';

/// Bottom navigation (Home, Search, Canvas, Collections) with a prominent +
/// action in the middle that opens the quick-create menu.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  // Destination slot 2 is the gap under the docked + button.
  static const _gap = 2;

  int get _destinationIndex =>
      shell.currentIndex >= _gap ? shell.currentIndex + 1 : shell.currentIndex;

  void _onDestinationSelected(int destination) {
    if (destination == _gap) return;
    final branch = destination > _gap ? destination - 1 : destination;
    // Tapping the active tab returns to its root.
    shell.goBranch(branch, initialLocation: branch == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      floatingActionButton: FloatingActionButton(
        tooltip: 'Create',
        onPressed: () => showQuickCreateSheet(context),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SketchDivider(height: 4, seed: 21),
          NavigationBar(
            selectedIndex: _destinationIndex,
            onDestinationSelected: _onDestinationSelected,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.desk_outlined),
                selectedIcon: Icon(Icons.desk),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_rounded),
                label: 'Search',
              ),
              ExcludeSemantics(child: SizedBox.shrink()),
              NavigationDestination(
                icon: Icon(Icons.gesture_rounded),
                label: 'Canvas',
              ),
              NavigationDestination(
                icon: Icon(Icons.collections_bookmark_outlined),
                selectedIcon: Icon(Icons.collections_bookmark),
                label: 'Collections',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The + menu: New Note, Scan Document, Draw, Record.
Future<void> showQuickCreateSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (sheetContext) {
      void open(String location) {
        Navigator.of(sheetContext).pop();
        context.push(location);
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_note_rounded),
              title: const Text('New note'),
              onTap: () => open(AppRoutes.newNote),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_customize_outlined),
              title: const Text('From template'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showTemplatePicker(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.document_scanner_outlined),
              title: const Text('Scan document'),
              onTap: () => open(AppRoutes.scan),
            ),
            ListTile(
              leading: const Icon(Icons.brush_outlined),
              title: const Text('Draw'),
              onTap: () => open(AppRoutes.newNoteWith(NoteMode.draw)),
            ),
            ListTile(
              leading: const Icon(Icons.mic_none_rounded),
              title: const Text('Record'),
              onTap: () => open(AppRoutes.newNoteWith(NoteMode.record)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

/// Secondary menu for settings and trash, for use in tab app bars.
class SecondaryMenuButton extends StatelessWidget {
  const SecondaryMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (location) => context.push(location),
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: AppRoutes.settings,
          child: ListTile(
            leading: Icon(Icons.settings_outlined),
            title: Text('Settings'),
          ),
        ),
        PopupMenuItem(
          value: AppRoutes.trash,
          child: ListTile(
            leading: Icon(Icons.delete_outline_rounded),
            title: Text('Trash'),
          ),
        ),
      ],
    );
  }
}
