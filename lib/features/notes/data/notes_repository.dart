import 'package:flutter/foundation.dart';

import '../../../core/storage/app_database.dart';
import '../../../core/storage/media_store.dart';
import '../domain/note.dart';

/// All notes, kept in memory and saved to the [AppDatabase], one row per
/// note. Listen to it to rebuild when notes change.
class NotesRepository extends ChangeNotifier {
  NotesRepository._(this._db, this._notes);

  static late NotesRepository instance;

  static Future<void> init() async {
    final db = AppDatabase.instance;
    instance = NotesRepository._(db, {
      for (final json in db.readAll(AppDatabase.notes))
        json['id']! as String: Note.fromJson(json),
    });
  }

  final AppDatabase _db;
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
    _db.put(AppDatabase.notes, note.id, note.toJson());
    _notes[note.id] = note;
    notifyListeners();
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

  /// Removes the note for good, with its recording.
  void delete(String id) {
    final note = _notes[id];
    if (note == null) return;
    _db.remove(AppDatabase.notes, id);
    _notes.remove(id);
    _deleteFiles(note);
    notifyListeners();
  }

  void emptyTrash() {
    final trashed = _notes.values.where((n) => n.inTrash).toList();
    _db.transaction(() {
      for (final note in trashed) {
        _db.remove(AppDatabase.notes, note.id);
      }
    });
    for (final note in trashed) {
      _notes.remove(note.id);
      _deleteFiles(note);
    }
    notifyListeners();
  }

  void _deleteFiles(Note note) {
    final audio = note.audio;
    if (audio != null) MediaStore.audio.delete(audio.fileName);
    final scan = note.scanFile;
    if (scan != null) MediaStore.scans.delete(scan);
  }
}
