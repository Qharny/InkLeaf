import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_note/core/storage/app_database.dart';
import 'package:my_note/core/storage/media_store.dart';
import 'package:my_note/features/canvas/domain/board.dart';
import 'package:my_note/features/notes/data/notes_repository.dart';
import 'package:my_note/features/notes/domain/note.dart';

void main() {
  final t = DateTime(2026, 1, 1);
  const stroke = BoardStroke(
    id: 's',
    points: [Offset(1, 2), Offset(3, 4)],
    color: 0xFF000000,
    width: 4,
  );

  test('a sketch-only note is not empty and is titled "Sketch"', () {
    final note = Note(
      id: 'n',
      sketch: const [stroke],
      createdAt: t,
      updatedAt: t,
    );
    expect(note.isEmpty, isFalse);
    expect(note.displayTitle, 'Sketch');
  });

  test('sketch survives a JSON round trip; old notes load without one', () {
    final note = Note(
      id: 'n',
      sketch: const [stroke],
      createdAt: t,
      updatedAt: t,
    );
    final back = Note.fromJson(
      (jsonDecode(jsonEncode(note.toJson())) as Map).cast<String, Object?>(),
    );
    expect(back.sketch.single.points, stroke.points);

    final old = Note(id: 'o', title: 'x', createdAt: t, updatedAt: t).toJson()
      ..remove('sketch');
    expect(Note.fromJson(old).sketch, isEmpty);
  });

  test('audio survives a JSON round trip and names the note', () {
    final note = Note(
      id: 'v',
      audio: const NoteAudio(fileName: 'voice_1.m4a', durationMs: 4200),
      createdAt: t,
      updatedAt: t,
    );
    expect(note.isEmpty, isFalse);
    expect(note.displayTitle, 'Voice note');
    final back = Note.fromJson(
      (jsonDecode(jsonEncode(note.toJson())) as Map).cast<String, Object?>(),
    );
    expect(back.audio!.fileName, 'voice_1.m4a');
    expect(back.audio!.duration, const Duration(milliseconds: 4200));
  });

  test('deleting a note for good deletes its recording', () async {
    AppDatabase.openInMemory();
    await NotesRepository.init();
    MediaStore.audio.directory = Directory.systemTemp.createTempSync(
      'inkleaf_t',
    );
    final file = File(MediaStore.audio.pathOf('voice_2.m4a'))
      ..writeAsStringSync('x');
    final repo = NotesRepository.instance
      ..save(
        Note(
          id: 'v',
          audio: const NoteAudio(fileName: 'voice_2.m4a', durationMs: 1),
          createdAt: t,
          updatedAt: t,
        ),
      );

    repo.moveToTrash('v');
    expect(file.existsSync(), isTrue, reason: 'trash keeps the audio');
    repo.emptyTrash();
    for (var i = 0; i < 20 && file.existsSync(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(file.existsSync(), isFalse);
  });

  test('checklists: saved, searched, and blank items count as empty', () {
    const items = [
      ChecklistItem(id: 'i1', text: 'Milk', done: true),
      ChecklistItem(id: 'i2', text: 'Eggs'),
    ];
    final note = Note(id: 'c', checklist: items, createdAt: t, updatedAt: t);
    expect(note.isEmpty, isFalse);
    expect(note.displayTitle, 'Milk');
    expect(note.matches('egg'), isTrue);

    final back = Note.fromJson(
      (jsonDecode(jsonEncode(note.toJson())) as Map).cast<String, Object?>(),
    );
    expect(
      [for (final i in back.checklist) (i.text, i.done)],
      [('Milk', true), ('Eggs', false)],
    );

    final blank = Note(
      id: 'b',
      checklist: [ChecklistItem.create()],
      createdAt: t,
      updatedAt: t,
    );
    expect(blank.isEmpty, isTrue);
  });
}
