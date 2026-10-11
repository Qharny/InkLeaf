import 'package:flutter/material.dart';

import '../data/notes_repository.dart';
import '../domain/note.dart';

// Formatting and links in a note's text. The text itself stays plain
// Markdown-ish (`# heading`, `**bold**`, `*italic*`, `~~strike~~`, `- item`,
// `[[Note title]]`), so search and backups see ordinary text; the editor
// just draws it styled.

final _heading = RegExp(r'^(#{1,3}) ');
final _bullet = RegExp(r'^(\s*)([-*]) ');
final _numbered = RegExp(r'^(\s*)(\d+\.) ');
final _inlineMarks = RegExp(
  r'(\*\*)(.+?)(\*\*)'
  r'|(~~)(.+?)(~~)'
  r'|(\[\[)(.+?)(\]\])'
  r'|(?<![*\w])(\*)(?!\s)(.+?)(\*)',
);
final _links = RegExp(r'\[\[(.+?)\]\]');
final _openLink = RegExp(r'\[\[([^\[\]\n]*)$');

/// A text controller that draws formatting as you type: headings larger,
/// bold, italic, strike-through, bullets and `[[links]]`, with the marks
/// themselves faded.
class MarkdownController extends TextEditingController {
  MarkdownController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final base = style ?? const TextStyle();
    final mark = base.copyWith(
      color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
    );
    final lines = text.split('\n');
    return TextSpan(
      style: base,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) const TextSpan(text: '\n'),
          ..._line(lines[i], base, mark, scheme),
        ],
      ],
    );
  }

  List<InlineSpan> _line(
    String line,
    TextStyle base,
    TextStyle mark,
    ColorScheme scheme,
  ) {
    if (_heading.firstMatch(line) case final h?) {
      final scale = const [1.45, 1.25, 1.12][h[1]!.length - 1];
      final style = base.copyWith(
        fontSize: (base.fontSize ?? 16) * scale,
        fontWeight: FontWeight.w700,
      );
      return [
        TextSpan(
          text: h[0],
          style: mark.copyWith(fontSize: style.fontSize),
        ),
        ..._inline(line.substring(h.end), style, mark, scheme),
      ];
    }
    final list = _bullet.firstMatch(line) ?? _numbered.firstMatch(line);
    if (list != null) {
      final isBullet = list[2] == '-' || list[2] == '*';
      return [
        TextSpan(text: list[1]),
        // Same length as the "-" it stands in for, so the caret still fits.
        TextSpan(
          text: isBullet ? '•' : list[2],
          style: base.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const TextSpan(text: ' '),
        ..._inline(line.substring(list.end), base, mark, scheme),
      ];
    }
    return _inline(line, base, mark, scheme);
  }

  List<InlineSpan> _inline(
    String text,
    TextStyle style,
    TextStyle mark,
    ColorScheme scheme,
  ) {
    final faded = mark.copyWith(fontSize: style.fontSize);
    final spans = <InlineSpan>[];
    var at = 0;
    for (final m in _inlineMarks.allMatches(text)) {
      if (m.start > at) {
        spans.add(TextSpan(text: text.substring(at, m.start), style: style));
      }
      final (open, inner, close, look) = switch (m) {
        _ when m[1] != null => (
          m[1]!,
          m[2]!,
          m[3]!,
          style.copyWith(fontWeight: FontWeight.w700),
        ),
        _ when m[4] != null => (
          m[4]!,
          m[5]!,
          m[6]!,
          style.copyWith(
            decoration: TextDecoration.lineThrough,
            color: scheme.onSurfaceVariant,
          ),
        ),
        _ when m[7] != null => (
          m[7]!,
          m[8]!,
          m[9]!,
          style.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
            decorationColor: scheme.primary,
          ),
        ),
        _ => (
          m[10]!,
          m[11]!,
          m[12]!,
          style.copyWith(fontStyle: FontStyle.italic),
        ),
      };
      spans
        ..add(TextSpan(text: open, style: faded))
        ..add(TextSpan(text: inner, style: look))
        ..add(TextSpan(text: close, style: faded));
      at = m.end;
    }
    if (at < text.length) {
      spans.add(TextSpan(text: text.substring(at), style: style));
    }
    return spans;
  }
}

TextSelection _selectionOf(TextEditingValue v) => v.selection.isValid
    ? v.selection
    : TextSelection.collapsed(offset: v.text.length);

/// Wraps the selection in [mark] (e.g. `**`), or puts the caret between a
/// fresh pair when nothing is selected.
void wrapSelection(TextEditingController c, String mark) {
  final v = c.value;
  final sel = _selectionOf(v);
  final picked = v.text.substring(sel.start, sel.end);
  c.value = TextEditingValue(
    text: v.text.replaceRange(sel.start, sel.end, '$mark$picked$mark'),
    selection: sel.isCollapsed
        ? TextSelection.collapsed(offset: sel.start + mark.length)
        : TextSelection(
            baseOffset: sel.start + mark.length,
            extentOffset: sel.end + mark.length,
          ),
  );
}

/// Types [text] at the caret, replacing any selection.
void insertAtCaret(TextEditingController c, String text) {
  final v = c.value;
  final sel = _selectionOf(v);
  c.value = TextEditingValue(
    text: v.text.replaceRange(sel.start, sel.end, text),
    selection: TextSelection.collapsed(offset: sel.start + text.length),
  );
}

/// Adds [prefix] to the caret's line, swaps it for a similar prefix matched
/// by [family] (another heading level or list style), or removes it if the
/// line already has it.
void toggleLinePrefix(TextEditingController c, String prefix, RegExp family) {
  final v = c.value;
  final caret = _selectionOf(v).start;
  final lineStart = caret == 0 ? 0 : v.text.lastIndexOf('\n', caret - 1) + 1;
  final current = family.matchAsPrefix(v.text, lineStart)?[0];
  final replace = current ?? '';
  final insert = current == prefix ? '' : prefix;
  final newText = v.text.replaceRange(
    lineStart,
    lineStart + replace.length,
    insert,
  );
  c.value = TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(
      offset: (caret + insert.length - replace.length).clamp(
        lineStart,
        newText.length,
      ),
    ),
  );
}

/// What's typed after an unclosed `[[` just before the caret, or null.
String? linkQuery(TextEditingValue v) {
  if (!v.selection.isValid || !v.selection.isCollapsed) return null;
  return _openLink.firstMatch(v.text.substring(0, v.selection.start))?[1];
}

/// Replaces the `[[query` being typed with a finished `[[title]]` link.
void completeLink(TextEditingController c, String title) {
  final v = c.value;
  final caret = _selectionOf(v).start;
  final open = _openLink.firstMatch(v.text.substring(0, caret));
  if (open == null) return;
  var end = caret;
  if (v.text.startsWith(']]', end)) end += 2;
  final link = '[[$title]]';
  c.value = TextEditingValue(
    text: v.text.replaceRange(open.start, end, link),
    selection: TextSelection.collapsed(offset: open.start + link.length),
  );
}

/// The note titles [text] links to, in order, without repeats.
List<String> linkedTitles(String text) {
  final seen = <String>{};
  return [
    for (final m in _links.allMatches(text))
      if (seen.add(m[1]!.trim().toLowerCase())) m[1]!.trim(),
  ];
}

/// The note shown as [title] (titles are matched ignoring case).
Note? noteTitled(String title) {
  final key = title.toLowerCase();
  for (final n in NotesRepository.instance.notes) {
    if (n.displayTitle.toLowerCase() == key) return n;
  }
  return null;
}

/// Notes whose text links to [note].
List<Note> notesLinkingTo(Note note) {
  final key = note.displayTitle.toLowerCase();
  return [
    for (final n in NotesRepository.instance.notes)
      if (n.id != note.id &&
          linkedTitles(n.body).any((t) => t.toLowerCase() == key))
        n,
  ];
}

/// The formatting buttons shown above the keyboard while writing a note.
class FormatToolbar extends StatelessWidget {
  const FormatToolbar({
    super.key,
    required this.controller,
    required this.onEdited,
  });

  final TextEditingController controller;

  /// Called with the new text after a button changes it.
  final ValueChanged<String> onEdited;

  static final _headings = RegExp(r'#{1,3} ');
  static final _lists = RegExp(r'([-*]|\d+\.) ');

  @override
  Widget build(BuildContext context) {
    Widget button(String tip, IconData icon, void Function() edit) =>
        IconButton(
          tooltip: tip,
          icon: Icon(icon),
          onPressed: () {
            edit();
            onEdited(controller.text);
          },
        );
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              button(
                'Heading',
                Icons.title_rounded,
                () => toggleLinePrefix(controller, '## ', _headings),
              ),
              button(
                'Bold',
                Icons.format_bold_rounded,
                () => wrapSelection(controller, '**'),
              ),
              button(
                'Italic',
                Icons.format_italic_rounded,
                () => wrapSelection(controller, '*'),
              ),
              button(
                'Strike through',
                Icons.format_strikethrough_rounded,
                () => wrapSelection(controller, '~~'),
              ),
              button(
                'Bulleted list',
                Icons.format_list_bulleted_rounded,
                () => toggleLinePrefix(controller, '- ', _lists),
              ),
              button(
                'Numbered list',
                Icons.format_list_numbered_rounded,
                () => toggleLinePrefix(controller, '1. ', _lists),
              ),
              button(
                'Link to a note',
                Icons.add_link_rounded,
                () => insertAtCaret(controller, '[['),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Notes matching the `[[...` being typed, to pick one as the link.
class LinkSuggestions extends StatelessWidget {
  const LinkSuggestions({
    super.key,
    required this.query,
    required this.exceptId,
    required this.onPick,
  });

  final String query;
  final String exceptId;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final matches = [
      for (final n in NotesRepository.instance.notes)
        if (n.id != exceptId && n.displayTitle.toLowerCase().contains(q))
          n.displayTitle,
    ].take(8).toList();
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            for (final title in matches)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  avatar: const Icon(Icons.link_rounded, size: 18),
                  label: Text(title),
                  onPressed: () => onPick(title),
                ),
              ),
            if (matches.isEmpty)
              Center(
                child: Text(
                  q.isEmpty
                      ? 'Type a note’s title to link it'
                      : 'No note called “$query” yet: close with ]] to '
                            'link it anyway',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Under a note's text: the notes it links to, and the notes that link to
/// it. A link to a note that doesn't exist yet offers to create it.
class NoteLinks extends StatelessWidget {
  const NoteLinks({
    super.key,
    required this.note,
    required this.onOpen,
    required this.onCreate,
  });

  final Note note;
  final ValueChanged<Note> onOpen;
  final ValueChanged<String> onCreate;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NotesRepository.instance,
      builder: (context, _) {
        final links = linkedTitles(note.body);
        final from = notesLinkingTo(note);
        if (links.isEmpty && from.isEmpty) return const SizedBox.shrink();
        final label = Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (links.isNotEmpty) ...[
              Text('Links to', style: label),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final title in links)
                    if (noteTitled(title) case final target?)
                      ActionChip(
                        avatar: const Icon(Icons.link_rounded, size: 18),
                        label: Text(target.displayTitle),
                        onPressed: () => onOpen(target),
                      )
                    else
                      ActionChip(
                        avatar: const Icon(Icons.add_rounded, size: 18),
                        label: Text('Create “$title”'),
                        onPressed: () => onCreate(title),
                      ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (from.isNotEmpty) ...[
              Text('Linked from', style: label),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final n in from)
                    ActionChip(
                      avatar: const Icon(
                        Icons.subdirectory_arrow_left_rounded,
                        size: 18,
                      ),
                      label: Text(n.displayTitle),
                      onPressed: () => onOpen(n),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
