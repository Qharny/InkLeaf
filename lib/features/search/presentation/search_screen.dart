import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_shell.dart';
import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/sketch_styles.dart';
import '../../../core/storage/app_prefs.dart';
import '../../../core/utils/relative_time.dart';
import '../../../core/widgets/doodles.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/domain/note.dart';
import '../../notes/presentation/note_card.dart';
import '../domain/note_search.dart';

/// "Find anything": search every note by words or #tags, with recent
/// searches and tags to browse while the box is empty.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialQuery});

  /// From the `?q=` query parameter.
  final String? initialQuery;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _repo = NotesRepository.instance;
  final _focus = FocusNode();
  late final _controller = TextEditingController(
    text: widget.initialQuery ?? '',
  );
  List<String> _recent = AppPrefs.instance.recentSearches;
  bool _pinnedOnly = false;

  String get _query => _controller.text;

  @override
  void didUpdateWidget(SearchScreen old) {
    super.didUpdateWidget(old);
    final q = widget.initialQuery;
    if (q != null && q != old.initialQuery) _setQuery(q, focus: false);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _setQuery(String query, {bool focus = true}) {
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    setState(() {});
    if (focus) _focus.requestFocus();
  }

  void _remember() {
    AppPrefs.instance.addRecentSearch(_query);
    setState(() => _recent = AppPrefs.instance.recentSearches);
  }

  void _forget(String query) {
    AppPrefs.instance.removeRecentSearch(query);
    setState(() => _recent = AppPrefs.instance.recentSearches);
  }

  void _clearRecent() {
    AppPrefs.instance.clearRecentSearches();
    setState(() => _recent = const []);
  }

  void _open(Note note) {
    _remember();
    _focus.unfocus();
    context.push(AppRoutes.noteById(note.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        actions: const [SecondaryMenuButton()],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _remember(),
              decoration: InputDecoration(
                hintText: 'Search titles, text and #tags',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => _setQuery(''),
                      ),
              ),
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: _repo,
              builder: (context, _) => searchTerms(_query).isEmpty
                  ? _buildIdle(context)
                  : _buildResults(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdle(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final tags = _repo.tags;
    final hasNotes = _repo.notes.isNotEmpty;

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        if (_recent.isNotEmpty) ...[
          _Heading(
            title: 'Recent searches',
            trailing: TextButton(
              onPressed: _clearRecent,
              child: const Text('Clear'),
            ),
          ),
          for (final recent in _recent)
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: Text(recent),
              onTap: () => _setQuery(recent),
              trailing: IconButton(
                tooltip: 'Remove "$recent"',
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => _forget(recent),
              ),
            ),
        ],
        if (tags.isNotEmpty) ...[
          const _Heading(title: 'Browse by tag'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in tags)
                  ActionChip(
                    label: Text('#$tag'),
                    onPressed: () => _setQuery('#$tag'),
                  ),
              ],
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 48, 32, 0),
          child: Column(
            children: [
              const SparkRays(size: 36, angle: -1.57),
              const SizedBox(height: 8),
              Text(
                hasNotes ? 'Find anything' : 'Nothing to search yet',
                style: text.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                hasNotes
                    ? 'Search words in your titles and notes, or type #tag '
                          'to find notes by tag.'
                    : 'Once you write some notes, you can find them here.',
                style: text.bodyLarge?.copyWith(color: muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResults(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final terms = searchTerms(_query);
    final hits = searchNotes(
      _repo.notes,
      _query,
    ).where((h) => !_pinnedOnly || h.note.pinned).toList();
    final count = switch (hits.length) {
      0 => 'No results',
      1 => '1 result',
      final n => '$n results',
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(count, style: text.titleMedium),
                ),
              ),
              FilterChip(
                label: const Text('Pinned only'),
                selected: _pinnedOnly,
                onSelected: (v) => setState(() => _pinnedOnly = v),
              ),
            ],
          ),
        ),
        Expanded(
          child: hits.isEmpty
              ? _NoResults(query: _query.trim())
              : ListView.separated(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: hits.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _ResultTile(
                    hit: hits[i],
                    terms: terms,
                    onTap: () => _open(hits[i].note),
                  ),
                ),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.hit,
    required this.terms,
    required this.onTap,
  });

  final SearchHit hit;
  final List<String> terms;
  final VoidCallback onTap;

  bool _tagMatched(String tag) => terms.any(
    (t) => t.startsWith('#') ? tag.startsWith(t.substring(1)) : tag.contains(t),
  );

  @override
  Widget build(BuildContext context) {
    final note = hit.note;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Material(
      color: noteFill(context, note.color),
      shape: SketchBorder(
        side: BorderSide(
          color: scheme.outline,
          width: SketchStyles.strokeWidth,
        ),
        seed: note.id.hashCode,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text.rich(
                      highlightMatches(
                        note.displayTitle,
                        terms,
                        text.titleLarge?.copyWith(fontSize: 18),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (note.pinned)
                    Icon(
                      Icons.push_pin_rounded,
                      size: 18,
                      semanticLabel: 'Pinned',
                      color: scheme.onSurface,
                    ),
                ],
              ),
              if (hit.snippet.isNotEmpty && hit.snippet != note.displayTitle)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text.rich(
                    highlightMatches(
                      hit.snippet,
                      terms,
                      text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final tag in note.tags)
                          Text(
                            '#$tag',
                            style: text.labelMedium?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                              backgroundColor: _tagMatched(tag)
                                  ? AppColors.markerYellow
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    relativeTime(note.updatedAt),
                    style: text.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [source] with every occurrence of the plain (non-#) [terms] drawn over
/// in yellow marker.
TextSpan highlightMatches(String source, List<String> terms, TextStyle? style) {
  final lower = source.toLowerCase();
  final ranges = <(int, int)>[];
  for (final term in terms.where((t) => !t.startsWith('#'))) {
    for (var i = lower.indexOf(term); i != -1; i = lower.indexOf(term, i + 1)) {
      ranges.add((i, i + term.length));
    }
  }
  if (ranges.isEmpty) return TextSpan(text: source, style: style);

  // Merge overlapping matches so each character is highlighted once.
  ranges.sort((a, b) => a.$1.compareTo(b.$1));
  final merged = <(int, int)>[ranges.first];
  for (final (start, end) in ranges.skip(1)) {
    final (lastStart, lastEnd) = merged.last;
    if (start <= lastEnd) {
      merged.last = (lastStart, end > lastEnd ? end : lastEnd);
    } else {
      merged.add((start, end));
    }
  }

  const marked = TextStyle(backgroundColor: AppColors.markerYellow);
  final spans = <TextSpan>[];
  var at = 0;
  for (final (start, end) in merged) {
    if (start > at) spans.add(TextSpan(text: source.substring(at, start)));
    spans.add(TextSpan(text: source.substring(start, end), style: marked));
    at = end;
  }
  if (at < source.length) spans.add(TextSpan(text: source.substring(at)));
  return TextSpan(style: style, children: spans);
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 96),
      child: Column(
        children: [
          const SquiggleDoodle(width: 90),
          const SizedBox(height: 16),
          Text(
            'Nothing found for “$query”',
            style: text.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Try fewer words, or check the spelling.',
            style: text.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
