import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/sketch_styles.dart';
import '../../../core/storage/app_prefs.dart';
import '../../../core/widgets/app_logo.dart';
import '../../backup/data/backup_io.dart';
import '../../backup/data/backup_service.dart';
import '../../canvas/data/boards_repository.dart';
import '../../collections/data/collections_repository.dart';
import '../../notes/data/notes_repository.dart';

/// Appearance, search history, a look at what's stored, and about.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _prefs = AppPrefs.instance;

  void _clearRecentSearches() {
    _prefs.clearRecentSearches();
    setState(() {});
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          persist: false,
          duration: Duration(seconds: 3),
          content: Text('Recent searches cleared'),
        ),
      );
  }

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final now = DateTime.now();
      await BackupIo.create().share(
        BackupService.export(now: now),
        BackupService.fileName(now),
      );
    } on Exception {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            persist: false,
            duration: Duration(seconds: 3),
            content: Text("Couldn't create the backup"),
          ),
        );
    }
  }

  Future<void> _restore() async {
    final messenger = ScaffoldMessenger.of(context);
    final bytes = await BackupIo.create().pick();
    if (bytes == null) return;
    final String message;
    try {
      final restored = BackupService.restore(bytes);
      NotesRepository.instance.reload();
      BoardsRepository.instance.reload();
      CollectionsRepository.instance.reload();
      message = restored.notes + restored.boards + restored.collections == 0
          ? 'Everything in that backup is already here'
          : 'Restored ${[_count(restored.notes, 'note'), _count(restored.boards, 'canvas'), _count(restored.collections, 'collection')].join(', ')}';
    } on FormatException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            persist: false,
            duration: const Duration(seconds: 3),
            content: Text("Can't restore: ${e.message}"),
          ),
        );
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          persist: false,
          duration: const Duration(seconds: 3),
          content: Text(message),
        ),
      );
  }

  Future<void> _replayIntro() async {
    await _prefs.resetOnboarding();
    if (mounted) context.go(AppRoutes.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    final notes = NotesRepository.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const _Section('Appearance'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: ValueListenableBuilder(
              valueListenable: _prefs.themeMode,
              builder: (context, mode, _) => SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('Paper'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('Night'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_outlined),
                    label: Text('System'),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (s) => _prefs.setThemeMode(s.single),
              ),
            ),
          ),
          const _Section('Search'),
          ListTile(
            leading: const Icon(Icons.history_rounded),
            title: const Text('Clear recent searches'),
            subtitle: Text(switch (_prefs.recentSearches.length) {
              0 => 'Nothing saved',
              1 => '1 saved search',
              final n => '$n saved searches',
            }),
            enabled: _prefs.recentSearches.isNotEmpty,
            onTap: _clearRecentSearches,
          ),
          const _Section('Your notebook'),
          ListenableBuilder(
            listenable: Listenable.merge([
              notes,
              BoardsRepository.instance,
              CollectionsRepository.instance,
            ]),
            builder: (context, _) => Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: const Text('Stored on this device'),
                  subtitle: Text(
                    [
                      _count(notes.notes.length, 'note'),
                      _count(BoardsRepository.instance.boards.length, 'canvas'),
                      _count(
                        CollectionsRepository.instance.collections.length,
                        'collection',
                      ),
                    ].join(' · '),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Trash'),
                  subtitle: Text(_count(notes.trashed.length, 'note')),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppRoutes.trash),
                ),
              ],
            ),
          ),
          const _Section('Backup'),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Export a backup'),
            subtitle: const Text(
              'Notes, canvases, collections, recordings and scans in one '
              '.zip you can save or send',
            ),
            onTap: _export,
          ),
          ListTile(
            leading: const Icon(Icons.restore_rounded),
            title: const Text('Restore from a backup'),
            subtitle: const Text(
              'Adds what is missing here and keeps the newer copy of '
              'anything changed in both places. Nothing is deleted.',
            ),
            onTap: _restore,
          ),
          const _Section('About'),
          ListTile(
            leading: const Icon(Icons.replay_rounded),
            title: const Text('Replay the intro'),
            onTap: _replayIntro,
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Open-source licenses'),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Inkleaf',
              applicationIcon: const Padding(
                padding: EdgeInsets.all(8),
                child: AppLogo(size: 48),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(child: AppLogo(size: 40, showName: true)),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Your thoughts, in ink.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _count(int n, String noun) {
  final plural = noun.endsWith('s') ? '${noun}es' : '${noun}s';
  return '$n ${n == 1 ? noun : plural}';
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: MarkerHighlight(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
      ),
    );
  }
}
