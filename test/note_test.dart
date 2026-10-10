import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_note/features/canvas/domain/board.dart';
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
}
