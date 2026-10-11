import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_note/core/storage/app_database.dart';
import 'package:my_note/features/collections/data/collections_repository.dart';
import 'package:my_note/features/collections/domain/collection.dart';

void main() {
  test('withNote adds once, newest first; withoutNote removes', () {
    final c = Collection.create(name: 'Trips').withNote('a').withNote('b');
    expect(c.noteIds, ['b', 'a']);
    expect(c.withNote('a').noteIds, ['b', 'a']);
    expect(c.withoutNote('b').noteIds, ['a']);
  });

  test('JSON round trip', () {
    final c = Collection.create(
      name: 'Recipes',
      description: 'Food',
      cover: 3,
    ).withNote('n1');
    final back = Collection.fromJson(
      (jsonDecode(jsonEncode(c.toJson())) as Map).cast<String, Object?>(),
    );
    expect(
      (back.id, back.name, back.description, back.cover),
      (c.id, 'Recipes', 'Food', 3),
    );
    expect(back.noteIds, ['n1']);
  });

  group('repository', () {
    late CollectionsRepository repo;
    late Collection a, b;

    setUp(() async {
      AppDatabase.openInMemory();
      await CollectionsRepository.init();
      repo = CollectionsRepository.instance;
      a = Collection.create(name: 'A');
      b = Collection.create(name: 'B');
      repo
        ..save(a)
        ..save(b);
    });

    test('setMembership puts a note in exactly the given collections', () {
      repo.setMembership('n', {a.id});
      expect(repo.containing('n').map((c) => c.name), ['A']);
      repo.setMembership('n', {b.id});
      expect(repo.containing('n').map((c) => c.name), ['B']);
      repo.setMembership('n', {});
      expect(repo.containing('n'), isEmpty);
    });

    test('setNotes keeps existing order and puts new notes first', () {
      repo
        ..addNote(a.id, 'x')
        ..addNote(a.id, 'y'); // [y, x]
      repo.setNotes(a.id, {'x', 'y', 'z'});
      expect(repo.byId(a.id)!.noteIds, ['z', 'y', 'x']);
      repo.setNotes(a.id, {'x'});
      expect(repo.byId(a.id)!.noteIds, ['x']);
    });

    test('changes are saved and survive a reload', () async {
      repo.addNote(a.id, 'n');
      await CollectionsRepository.init();
      expect(CollectionsRepository.instance.byId(a.id)!.noteIds, ['n']);
    });
  });
}
