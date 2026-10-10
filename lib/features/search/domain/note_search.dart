import '../../notes/domain/note.dart';

/// A note that matched a search, with a short excerpt around the match.
class SearchHit {
  const SearchHit({
    required this.note,
    required this.score,
    required this.snippet,
  });

  final Note note;
  final int score;

  /// Body text around the first match, or the start of the body.
  final String snippet;
}

/// Lower-cased words of [query]. Words starting with `#` match tags.
List<String> searchTerms(String query) => query
    .toLowerCase()
    .split(RegExp(r'\s+'))
    .where((t) => t.isNotEmpty && t != '#')
    .toList();

/// Notes matching every term in [query], best matches first.
///
/// A plain term matches the title, body or a tag; `#term` matches only tags
/// starting with "term". Title and tag matches rank above body matches, and
/// ties go to the most recently edited note.
List<SearchHit> searchNotes(Iterable<Note> notes, String query) {
  final terms = searchTerms(query);
  if (terms.isEmpty) return const [];

  final hits = <SearchHit>[];
  for (final note in notes) {
    final score = _score(note, terms);
    if (score == null) continue;
    hits.add(
      SearchHit(note: note, score: score, snippet: _snippet(note.body, terms)),
    );
  }

  hits.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0
        ? byScore
        : b.note.updatedAt.compareTo(a.note.updatedAt);
  });
  return hits;
}

/// Relevance of [note], or null if some term doesn't match.
int? _score(Note note, List<String> terms) {
  final title = note.title.toLowerCase();
  final body = note.body.toLowerCase();
  var score = 0;
  for (final term in terms) {
    if (term.startsWith('#')) {
      final tag = term.substring(1);
      if (note.tags.contains(tag)) {
        score += 4;
      } else if (note.tags.any((t) => t.startsWith(tag))) {
        score += 3;
      } else {
        return null;
      }
      continue;
    }
    var termScore = 0;
    if (title.contains(term)) termScore += title.startsWith(term) ? 6 : 4;
    if (note.tags.any((t) => t.contains(term))) termScore += 3;
    if (body.contains(term)) termScore += 1;
    if (termScore == 0) return null;
    score += termScore;
  }
  return score;
}

String _snippet(String body, List<String> terms) {
  const before = 30, length = 140;
  final flat = body.replaceAll(RegExp(r'\s+'), ' ').trim();
  final lower = flat.toLowerCase();
  var at = -1;
  for (final term in terms.where((t) => !t.startsWith('#'))) {
    final i = lower.indexOf(term);
    if (i != -1 && (at == -1 || i < at)) at = i;
  }
  final start = at <= before ? 0 : at - before;
  final end = start + length >= flat.length ? flat.length : start + length;
  return '${start > 0 ? '…' : ''}${flat.substring(start, end).trim()}'
      '${end < flat.length ? '…' : ''}';
}
