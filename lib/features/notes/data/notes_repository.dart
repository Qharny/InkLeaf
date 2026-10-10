import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/note.dart';

/// All notes, kept in memory and saved to [SharedPreferences] as JSON.
///
/// Listen to it to rebuild when notes change.
class NotesRepository extends ChangeNotifier {
  NotesRepository._(this._prefs, this._notes);

  static late NotesRepository instance;

  static const _key = 'notes';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final notes = <String, Note>{};
    if (raw != null) {
      for (final json in (jsonDecode(raw) as List<Object?>)) {
        final note = Note.fromJson((json! as Map).cast<String, Object?>());
        notes[note.id] = note;
      }
    }
    instance = NotesRepository._(prefs, notes);
  }

  final SharedPreferences _prefs;
  final Map<String, Note> _notes;

  /// Notes not in the trash, most recently edited first.
  List<Note> get notes =>
      _notes.values.where((n) => !n.inTrash).toList()
        ..sort(NoteSort.edited.compare);

  /// Trashed notes, most recently deleted first.
  List<Note> get trashed =>
      _notes.values.where((n) => n.inTrash).toList()
        ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));

  /// Every tag used by a note outside the trash, alphabetically.
  List<String> get tags =>
      {for (final n in _notes.values.where((n) => !n.inTrash)) ...n.tags}
          .toList()
        ..sort();

  Note? byId(String id) => _notes[id];

  /// Adds [note] or replaces the note with the same id.
  void save(Note note) {
    _notes[note.id] = note;
    _changed();
  }

  void togglePin(String id) {
    final note = _notes[id];
    if (note == null) return;
    save(note.copyWith(pinned: !note.pinned));
  }

  void setColor(String id, int color) {
    final note = _notes[id];
    if (note == null) return;
    save(note.copyWith(color: color));
  }

  void moveToTrash(String id) {
    final note = _notes[id];
    if (note == null) return;
    save(note.copyWith(pinned: false, deletedAt: DateTime.now));
  }

  void restore(String id) {
    final note = _notes[id];
    if (note == null) return;
    save(note.copyWith(deletedAt: () => null));
  }

  /// Removes the note for good.
  void delete(String id) {
    if (_notes.remove(id) != null) _changed();
  }

  void emptyTrash() {
    _notes.removeWhere((_, n) => n.inTrash);
    _changed();
  }

  void _changed() {
    notifyListeners();
    _prefs.setString(
      _key,
      jsonEncode([for (final n in _notes.values) n.toJson()]),
    );
  }
}
