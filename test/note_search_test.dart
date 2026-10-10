import 'package:flutter_test/flutter_test.dart';
import 'package:my_note/features/notes/domain/note.dart';
import 'package:my_note/features/search/domain/note_search.dart';

Note _note(
  String id,
  String title, {
  String body = '',
  List<String> tags = const [],
  int day = 1,
}) => Note(
  id: id,
  title: title,
  body: body,
  tags: tags,
  createdAt: DateTime(2026, 1, day),
  updatedAt: DateTime(2026, 1, day),
);

void main() {
  final notes = [
    _note('a', 'Groceries', body: 'eggs, milk, bread'),
    _note('b', 'Trip to Accra', body: 'Pack the camera', tags: ['travel']),
    _note('c', 'Camera settings', body: 'ISO 400', day: 2),
    _note('d', 'Ideas', body: 'An app for travel journals', tags: ['ideas']),
  ];
  List<String> ids(String q) => [
    for (final h in searchNotes(notes, q)) h.note.id,
  ];

  test('blank query finds nothing', () {
    expect(searchNotes(notes, '   '), isEmpty);
    expect(searchNotes(notes, '#'), isEmpty);
  });

  test('matches title, body and tags, case-insensitively', () {
    expect(ids('MILK'), ['a']);
    expect(ids('travel').toSet(), {'b', 'd'});
  });

  test('title matches rank above body matches', () {
    expect(ids('camera'), ['c', 'b']);
  });

  test('every word must match', () {
    expect(ids('camera pack'), ['b']);
    expect(ids('camera milk'), isEmpty);
  });

  test('#tag matches tags only, by prefix', () {
    expect(ids('#trav'), ['b']);
    expect(ids('#camera'), isEmpty);
    expect(ids('#ideas app'), ['d']);
  });

  test('snippet centers on the match with ellipses', () {
    final long = _note(
      'e',
      'Long',
      body: '${'word ' * 30}needle${' tail' * 40}',
    );
    final hit = searchNotes([long], 'needle').single;
    expect(hit.snippet, startsWith('…'));
    expect(hit.snippet, endsWith('…'));
    expect(hit.snippet, contains('needle'));
  });
}
