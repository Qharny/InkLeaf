import 'package:flutter_test/flutter_test.dart';
import 'package:my_note/core/storage/app_database.dart';
import 'package:my_note/core/storage/app_prefs.dart';
import 'package:my_note/features/canvas/data/boards_repository.dart';
import 'package:my_note/features/canvas/domain/board.dart';
import 'package:my_note/features/collections/data/collections_repository.dart';
import 'package:my_note/features/notes/data/notes_repository.dart';
import 'package:my_note/features/notes/data/starter_notebook.dart';
import 'package:my_note/features/notes/domain/note.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A fresh install, with [prefs] already saved.
Future<void> _launch([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  await AppPrefs.init();
  AppDatabase.openInMemory();
  await NotesRepository.init();
  await BoardsRepository.init();
  await CollectionsRepository.init();
}

void main() {
  List<Note> notes() => NotesRepository.instance.notes;

  test('a fresh install gets the starter notes and canvas', () async {
    await _launch();
    StarterNotebook.addIfNew();

    expect(notes().map((n) => n.title), [
      'Start here',
      'Tick things off',
      'Find anything',
    ]);
    expect(notes().first.pinned, isTrue);
    expect(BoardsRepository.instance.boards.single.title, 'Ideas, laid out');
    expect(AppPrefs.instance.starterAdded, isTrue);
  });

  test('every link and canvas card points at a starter note', () async {
    await _launch();
    StarterNotebook.addIfNew();

    final titles = {for (final n in notes()) n.title};
    for (final note in notes()) {
      for (final link in RegExp(r'\[\[(.+?)\]\]').allMatches(note.body)) {
        expect(titles, contains(link[1]), reason: 'in "${note.title}"');
      }
    }
    final board = BoardsRepository.instance.boards.single;
    for (final card in board.cards.where((c) => c.kind == BoardCardKind.note)) {
      expect(NotesRepository.instance.byId(card.noteId!), isNotNull);
    }
  });

  test('the searches the notes suggest find them', () async {
    await _launch();
    StarterNotebook.addIfNew();

    List<String> search(String q) => [
      for (final n in notes())
        if (n.matches(q)) n.id,
    ];
    expect(
      search('pencil'),
      containsAll([StarterNotebook.checklistId, StarterNotebook.searchId]),
    );
    expect(search('start'), contains(StarterNotebook.searchId));
  });

  test('someone with notes already gets nothing, now or later', () async {
    await _launch();
    final t = DateTime(2026, 1, 1);
    NotesRepository.instance.save(
      Note(id: 'mine', title: 'Mine', createdAt: t, updatedAt: t),
    );
    StarterNotebook.addIfNew();
    expect(notes().map((n) => n.id), ['mine']);

    NotesRepository.instance.delete('mine');
    NotesRepository.instance.emptyTrash();
    StarterNotebook.addIfNew();
    expect(notes(), isEmpty);
    expect(BoardsRepository.instance.boards, isEmpty);
  });

  test('is added only once', () async {
    await _launch({'starter_added': true});
    StarterNotebook.addIfNew();
    expect(notes(), isEmpty);
  });
}
