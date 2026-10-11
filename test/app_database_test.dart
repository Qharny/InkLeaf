import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_note/core/storage/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, Object?> _doc(String id, [String title = '']) => {
  'id': id,
  'title': title,
};

void main() {
  setUp(AppDatabase.openInMemory);

  test('put, read, replace and remove documents', () {
    final db = AppDatabase.instance
      ..put(AppDatabase.notes, 'a', _doc('a', 'one'))
      ..put(AppDatabase.notes, 'a', _doc('a', 'two'))
      ..put(AppDatabase.notes, 'b', _doc('b'));
    expect(db.readAll(AppDatabase.notes), hasLength(2));
    expect(
      db.readAll(AppDatabase.notes).firstWhere((d) => d['id'] == 'a')['title'],
      'two',
    );
    db.remove(AppDatabase.notes, 'b');
    expect(db.readAll(AppDatabase.notes).single['id'], 'a');
    expect(db.readAll(AppDatabase.boards), isEmpty);
  });

  test('a failing transaction leaves nothing behind', () {
    final db = AppDatabase.instance;
    expect(
      () => db.transaction(() {
        db.put(AppDatabase.notes, 'a', _doc('a'));
        throw StateError('boom');
      }),
      throwsStateError,
    );
    expect(db.readAll(AppDatabase.notes), isEmpty);
  });

  test('imports old SharedPreferences data once, then removes it', () async {
    SharedPreferences.setMockInitialValues({
      'notes': jsonEncode([_doc('n1', 'Old note')]),
      'boards': jsonEncode([_doc('b1')]),
      'collections': jsonEncode([_doc('c1'), _doc('c2')]),
      'collections_order': ['c2', 'c1'],
      'theme_mode': 'dark',
    });
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.instance;

    await db.importLegacy(prefs);
    expect(db.readAll(AppDatabase.notes).single['title'], 'Old note');
    expect(db.readAll(AppDatabase.boards), hasLength(1));
    expect(db.readAll(AppDatabase.collections), hasLength(2));
    expect(db.meta(AppDatabase.collectionsOrderKey), '["c2","c1"]');
    expect(prefs.getString('notes'), isNull);
    expect(prefs.getStringList('collections_order'), isNull);
    expect(prefs.getString('theme_mode'), 'dark', reason: 'settings stay');

    // Later edits are not overwritten by a repeated import.
    db.put(AppDatabase.notes, 'n1', _doc('n1', 'Edited'));
    await db.importLegacy(prefs);
    expect(db.readAll(AppDatabase.notes).single['title'], 'Edited');
  });

  test('data survives closing and reopening the file', () {
    final dir = Directory.systemTemp.createTempSync('inkleaf_db');
    final path = '${dir.path}/inkleaf.db';
    AppDatabase.openFile(path);
    AppDatabase.instance
      ..put(AppDatabase.collections, 'c', _doc('c', 'Kept'))
      ..setMeta(AppDatabase.collectionsOrderKey, '["c"]')
      ..close();

    AppDatabase.openFile(path);
    expect(
      AppDatabase.instance.readAll(AppDatabase.collections).single['title'],
      'Kept',
    );
    expect(AppDatabase.instance.meta(AppDatabase.collectionsOrderKey), '["c"]');
    AppDatabase.instance.close();
    dir.deleteSync(recursive: true);
  });
}
