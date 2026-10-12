import 'dart:ui';

import '../../../core/storage/app_prefs.dart';
import '../../canvas/data/boards_repository.dart';
import '../../canvas/domain/board.dart';
import '../../collections/data/collections_repository.dart';
import '../domain/note.dart';
import 'notes_repository.dart';

/// A few notes and a canvas that show a new notebook around. They're
/// ordinary notes, so people can tick, edit and delete them.
abstract final class StarterNotebook {
  /// Fixed ids, so restoring a backup that has them merges instead of
  /// adding a second set.
  static const welcomeId = 'starter_welcome';
  static const checklistId = 'starter_checklist';
  static const searchId = 'starter_search';
  static const boardId = 'starter_board';

  /// Adds the starter notebook on a fresh install: only when nothing has
  /// been written yet, and never twice.
  static void addIfNew({DateTime? now}) {
    final prefs = AppPrefs.instance;
    if (prefs.starterAdded) return;
    final notes = NotesRepository.instance;
    final isEmpty =
        notes.notes.isEmpty &&
        notes.trashed.isEmpty &&
        BoardsRepository.instance.boards.isEmpty &&
        CollectionsRepository.instance.collections.isEmpty;
    // Someone who already has notes doesn't need the tour, now or later.
    prefs.markStarterAdded();
    if (!isEmpty) return;

    final t = now ?? DateTime.now();
    // Start here is the newest, so it sits at the top of the desk.
    DateTime at(int secondsAgo) => t.subtract(Duration(seconds: secondsAgo));
    for (final note in _notes(at)) {
      notes.save(note);
    }
    BoardsRepository.instance.save(_board(at(3)));
  }

  static List<Note> _notes(DateTime Function(int secondsAgo) at) => [
    Note(
      id: welcomeId,
      title: 'Start here',
      body:
          'Welcome to **Inkleaf**, your new notebook. These notes show you '
          'around. Delete them whenever you like.\n\n'
          '## Have a look\n'
          '- [[Tick things off]]: a checklist to play with\n'
          '- [[Find anything]]: try a search\n'
          '- *Ideas, laid out* is waiting under **Canvas** at the bottom\n\n'
          '## Make it yours\n'
          '- Tap **+** to write a note, make a checklist, sketch, record or '
          'scan a page\n'
          '- Long-press any card on your desk to pin it or move it to the '
          'trash',
      pinned: true,
      createdAt: at(0),
      updatedAt: at(0),
    ),
    Note(
      id: checklistId,
      title: 'Tick things off',
      body:
          'Tap a box to tick it off. Done items get a pencil line through '
          'them.\n\nBack to [[Start here]]',
      color: 2,
      checklist: const [
        ChecklistItem(id: 'starter_c1', text: 'Tick me off'),
        ChecklistItem(
          id: 'starter_c2',
          text: 'Already done: see the pencil line?',
          done: true,
        ),
        ChecklistItem(id: 'starter_c3', text: 'Add one of your own below'),
      ],
      createdAt: at(1),
      updatedAt: at(1),
    ),
    Note(
      id: searchId,
      title: 'Find anything',
      body:
          'Open **Search** and type *pencil*. Every note with that word turns '
          'up, with the word highlighted.\n\n'
          'Search looks through titles, text, checklists and tags. This note '
          'is tagged *start*, so searching for start finds it too. Scanned '
          'pages become text, so they turn up as well.\n\n'
          'Back to [[Start here]]',
      color: 1,
      tags: const ['start'],
      createdAt: at(2),
      updatedAt: at(2),
    ),
  ];

  static Board _board(DateTime when) {
    const x = boardSize / 2, y = boardSize / 2;
    return Board(
      id: boardId,
      title: 'Ideas, laid out',
      createdAt: when,
      updatedAt: when,
      cards: const [
        BoardCard(
          id: 'starter_k1',
          kind: BoardCardKind.sticky,
          text: 'Drag me around',
          x: x - 200,
          y: y - 220,
        ),
        BoardCard(
          id: 'starter_k2',
          kind: BoardCardKind.sticky,
          text: 'Double-tap a sticky note to write on it',
          color: 2,
          x: x + 60,
          y: y - 110,
          width: 170,
          height: 120,
        ),
        BoardCard(
          id: 'starter_k3',
          kind: BoardCardKind.sticky,
          text: 'Tap a card, then the arrow button, then another card',
          color: 1,
          x: x - 210,
          y: y + 60,
          width: 180,
          height: 130,
        ),
        BoardCard(
          id: 'starter_k4',
          kind: BoardCardKind.note,
          noteId: welcomeId,
          x: x + 50,
          y: y + 170,
          width: 200,
          height: 150,
        ),
      ],
      links: const [
        BoardLink(id: 'starter_l1', from: 'starter_k1', to: 'starter_k2'),
        BoardLink(id: 'starter_l2', from: 'starter_k1', to: 'starter_k3'),
        BoardLink(id: 'starter_l3', from: 'starter_k3', to: 'starter_k4'),
      ],
      strokes: [
        BoardStroke(
          id: 'starter_circle',
          color: 0xFFC0563B,
          width: 3,
          points: [
            // A loose pencil loop around "Drag me around".
            for (var a = 0.0; a <= 6.5; a += 0.15)
              const Offset(x - 120, y - 155) +
                  Offset.fromDirection(a, 125 * (1 + 0.04 * (a % 1))),
          ],
        ),
      ],
    );
  }
}
