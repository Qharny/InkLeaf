import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_shell.dart';
import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/sketch_styles.dart';
import '../../../core/navigation/pending_note.dart';
import '../../../core/storage/app_prefs.dart';
import '../../../core/utils/relative_time.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/doodles.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/domain/note.dart';
import '../../notes/presentation/bin_animation.dart';
import '../../notes/presentation/card_flight.dart';
import '../../notes/presentation/note_card.dart';

/// "Your desk": greeting, search, tag filters, pinned notes and the rest of
/// the notes as a grid or list.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repo = NotesRepository.instance;
  final _search = TextEditingController();
  String _query = '';
  String? _tag;
  bool _grid = AppPrefs.instance.homeGrid;
  NoteSort _sort = NoteSort.parse(AppPrefs.instance.noteSort);

  /// Each card's key, so a card can be found after it moves.
  final _cardKeys = <String, GlobalKey>{};

  /// Cards hidden while an animated copy travels to where they now are.
  final _hidden = <String>{};

  @override
  void initState() {
    super.initState();
    // Open notes from shares and tapped reminders, including one that
    // launched the app.
    pendingNoteToOpen.addListener(_openPending);
    pendingLocationToOpen.addListener(_openPending);
    BinEvents.note.addListener(_onRestored);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPending());
  }

  void _openPending() {
    if (!mounted) return;
    final id = pendingNoteToOpen.value;
    final location = pendingLocationToOpen.value;
    if (id != null) {
      pendingNoteToOpen.value = null;
      context.push(AppRoutes.noteById(id));
    } else if (location != null) {
      pendingLocationToOpen.value = null;
      context.push(location);
    }
  }

  @override
  void dispose() {
    pendingNoteToOpen.removeListener(_openPending);
    pendingLocationToOpen.removeListener(_openPending);
    BinEvents.note.removeListener(_onRestored);
    _search.dispose();
    super.dispose();
  }

  void _open(Note note) => context.push(AppRoutes.noteById(note.id));

  /// Hides note [id]'s card for a frame so it can be found in its new
  /// place, then lets [play] animate something into that place.
  Future<void> _arrive(String id, Future<void> Function(Rect to) play) async {
    setState(() => _hidden.add(id));
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final card = _cardKeys[id]?.currentContext;
    final to = card != null && card.mounted ? globalRectOf(card) : null;
    // Only when Home is the visible tab.
    if (to != null && TickerMode.valuesOf(context).enabled) await play(to);
    if (mounted) setState(() => _hidden.remove(id));
  }

  /// Pins or unpins with the card travelling to its new row.
  void _togglePin(Note note, BuildContext card) {
    final from = globalRectOf(card);
    _repo.togglePin(note.id);
    final moved = _repo.byId(note.id);
    if (from == null || moved == null) return;
    _arrive(
      note.id,
      (to) => flyNoteCard(context, note: moved, from: from, to: to),
    );
  }

  /// A note brought back by Undo comes out of the bin into its spot.
  void _onRestored() {
    final id = BinEvents.note.value;
    if (id == null) return;
    BinEvents.note.value = null;
    final note = _repo.byId(id);
    if (note == null || !mounted) return;
    _arrive(
      id,
      (to) =>
          pullFromBin(context, to: to, paper: noteFill(context, note.color)),
    );
  }

  /// A card that can be found after it moves, and hidden while it lands.
  Widget _card(Note note, Widget Function(BuildContext card) build) => Builder(
    key: _cardKeys.putIfAbsent(note.id, GlobalKey.new),
    builder: (card) =>
        Opacity(opacity: _hidden.contains(note.id) ? 0 : 1, child: build(card)),
  );

  void _toggleLayout() {
    setState(() => _grid = !_grid);
    AppPrefs.instance.setHomeGrid(_grid);
  }

  void _setSort(NoteSort sort) {
    setState(() => _sort = sort);
    AppPrefs.instance.setNoteSort(sort.name);
  }

  void _clearFilters() {
    _search.clear();
    setState(() {
      _query = '';
      _tag = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppLogo(size: 36, showName: true),
        actions: [
          IconButton(
            tooltip: _grid ? 'Show as list' : 'Show as grid',
            icon: Icon(
              _grid ? Icons.view_agenda_outlined : Icons.grid_view_rounded,
            ),
            onPressed: _toggleLayout,
          ),
          PopupMenuButton<NoteSort>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort_rounded),
            onSelected: _setSort,
            itemBuilder: (_) => [
              for (final sort in NoteSort.values)
                CheckedPopupMenuItem(
                  value: sort,
                  checked: sort == _sort,
                  child: Text(sort.label),
                ),
            ],
          ),
          const SecondaryMenuButton(),
        ],
      ),
      body: ListenableBuilder(listenable: _repo, builder: _buildBody),
    );
  }

  Widget _buildBody(BuildContext context, Widget? _) {
    final all = _repo.notes;
    final tags = _repo.tags;
    // A tag disappears when its last note is edited or trashed.
    final tag = tags.contains(_tag) ? _tag : null;
    final visible =
        all
            .where((n) => (tag == null || n.tags.contains(tag)))
            .where((n) => n.matches(_query))
            .toList()
          ..sort(_sort.compare);
    final pinned = visible.where((n) => n.pinned).toList();
    final others = visible.where((n) => !n.pinned).toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _Greeting(count: all.length)),
        if (all.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyDesk(onCreate: () => context.push(AppRoutes.newNote)),
          )
        else ...[
          SliverToBoxAdapter(child: _buildSearch(context)),
          if (tags.isNotEmpty)
            SliverToBoxAdapter(child: _buildTagFilter(tags, tag)),
          if (visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _NoMatches(onClear: _clearFilters),
            ),
          if (pinned.isNotEmpty) ...[
            const _SectionHeader(
              title: 'Pinned',
              icon: Icons.push_pin_outlined,
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 168,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: pinned.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => SizedBox(
                    width: 168,
                    // Builder: the long-press menu needs the card's own context,
                    // to throw it in the bin from where it sits.
                    child: _card(
                      pinned[i],
                      (card) => NoteCard(
                        note: pinned[i],
                        previewLines: 3,
                        onTap: () => _open(pinned[i]),
                        onLongPress: () => showNoteActions(
                          card,
                          pinned[i],
                          onTogglePin: () => _togglePin(pinned[i], card),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (others.isNotEmpty) ...[
            _SectionHeader(
              title: pinned.isEmpty ? 'Recent notes' : 'Everything else',
              icon: Icons.history_edu_outlined,
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: _grid
                  ? SliverGrid.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            mainAxisExtent: 184,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                          ),
                      itemCount: others.length,
                      itemBuilder: (_, i) => _card(
                        others[i],
                        (card) => NoteCard(
                          note: others[i],
                          onTap: () => _open(others[i]),
                          onLongPress: () => showNoteActions(
                            card,
                            others[i],
                            onTogglePin: () => _togglePin(others[i], card),
                          ),
                        ),
                      ),
                    )
                  : SliverList.separated(
                      itemCount: others.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _card(
                        others[i],
                        (card) => NoteCard(
                          note: others[i],
                          fixedHeight: false,
                          previewLines: 2,
                          onTap: () => _open(others[i]),
                          onLongPress: () => showNoteActions(
                            card,
                            others[i],
                            onTogglePin: () => _togglePin(others[i], card),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ],
        // Room to scroll the last row clear of the docked + button.
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }

  Widget _buildSearch(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _search,
        onChanged: (value) => setState(() => _query = value),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search your notes',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _search.clear();
                    setState(() => _query = '');
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildTagFilter(List<String> tags, String? selected) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        children: [
          for (final tag in [null, ...tags])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(tag == null ? 'All' : '#$tag'),
                selected: tag == selected,
                showCheckmark: false,
                onSelected: (_) => setState(() => _tag = tag),
              ),
            ),
        ],
      ),
    );
  }
}

/// Long-press menu for a note: pin, recolor, move to trash. [context] should
/// be the note's card, which "Move to trash" throws into the bin.
/// [onTogglePin] replaces the plain pin toggle (e.g. to animate the move).
Future<void> showNoteActions(
  BuildContext context,
  Note note, {
  VoidCallback? onTogglePin,
}) {
  final repo = NotesRepository.instance;
  final messenger = ScaffoldMessenger.of(context);
  final card = globalRectOf(context);
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (sheetContext) {
      final text = Theme.of(sheetContext).textTheme;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                note.displayTitle,
                style: text.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: NoteColorPicker(
                selected: note.color,
                onSelected: (color) {
                  repo.setColor(note.id, color);
                  Navigator.of(sheetContext).pop();
                },
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                note.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              ),
              title: Text(note.pinned ? 'Unpin' : 'Pin to top'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onTogglePin != null ? onTogglePin() : repo.togglePin(note.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Move to trash'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                if (card != null) {
                  throwInBin(
                    context,
                    from: card,
                    paper: noteFill(context, note.color),
                  );
                }
                moveNoteToTrash(messenger, note);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

/// Trashes [note] and offers to undo, restoring its pin too.
void moveNoteToTrash(ScaffoldMessengerState messenger, Note note) {
  final repo = NotesRepository.instance;
  repo.moveToTrash(note.id);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        persist: false,
        duration: const Duration(seconds: 3),
        content: const Text('Moved to trash'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            repo.restore(note.id);
            if (note.pinned) repo.togglePin(note.id);
            BinEvents.restored(BinEvents.note, note.id);
          },
        ),
      ),
    );
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final subtitle = switch (count) {
      0 => 'Your desk is clear.',
      1 => '1 note on your desk',
      _ => '$count notes on your desk',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MarkerHighlight(
                  color: AppColors.markerGreen,
                  child: Text(greeting(), style: text.headlineLarge),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: text.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const LeafDoodle(size: 40, rotation: 0.5),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}

class _EmptyDesk extends StatelessWidget {
  const _EmptyDesk({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 96),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Stack(
            clipBehavior: Clip.none,
            children: [
              LeafDoodle(size: 72, rotation: -0.3),
              Positioned(
                right: -28,
                top: -22,
                child: SparkRays(size: 36, angle: -0.8),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Nothing here yet',
            style: text.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Jot down a thought, a list or an idea. It will wait for you here.',
            style: text.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Write your first note'),
          ),
        ],
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 96),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SquiggleDoodle(width: 90),
          const SizedBox(height: 16),
          Text('No notes match', style: text.headlineSmall),
          const SizedBox(height: 8),
          TextButton(onPressed: onClear, child: const Text('Clear filters')),
        ],
      ),
    );
  }
}
