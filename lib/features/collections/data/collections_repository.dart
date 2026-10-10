import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/collection.dart';

/// All collections, kept in memory and saved to [SharedPreferences] as
/// JSON. Listen to it to rebuild when a collection changes.
class CollectionsRepository extends ChangeNotifier {
  CollectionsRepository._(this._prefs, this._collections);

  static late CollectionsRepository instance;

  static const _key = 'collections';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final collections = <String, Collection>{};
    if (raw != null) {
      for (final json in (jsonDecode(raw) as List<Object?>)) {
        final c = Collection.fromJson((json! as Map).cast<String, Object?>());
        collections[c.id] = c;
      }
    }
    instance = CollectionsRepository._(prefs, collections);
  }

  final SharedPreferences _prefs;
  final Map<String, Collection> _collections;

  /// Collections, most recently changed first.
  List<Collection> get collections =>
      _collections.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  Collection? byId(String id) => _collections[id];

  /// Collections containing [noteId].
  List<Collection> containing(String noteId) =>
      collections.where((c) => c.contains(noteId)).toList();

  /// Adds [collection] or replaces the one with the same id.
  void save(Collection collection) {
    _collections[collection.id] = collection;
    _changed();
  }

  /// Removes the collection. Its notes are untouched.
  void delete(String id) {
    if (_collections.remove(id) != null) _changed();
  }

  void addNote(String collectionId, String noteId) {
    final c = _collections[collectionId];
    if (c == null || c.contains(noteId)) return;
    save(c.withNote(noteId).copyWith(updatedAt: DateTime.now()));
  }

  void removeNote(String collectionId, String noteId) {
    final c = _collections[collectionId];
    if (c == null || !c.contains(noteId)) return;
    save(c.withoutNote(noteId).copyWith(updatedAt: DateTime.now()));
  }

  /// Makes [noteIds] exactly the notes in the collection, keeping the
  /// existing order and putting new ones first.
  void setNotes(String collectionId, Set<String> noteIds) {
    final c = _collections[collectionId];
    if (c == null) return;
    final kept = c.noteIds.where(noteIds.contains).toList();
    final added = noteIds.where((id) => !c.contains(id)).toList();
    if (added.isEmpty && kept.length == c.noteIds.length) return;
    save(c.copyWith(noteIds: [...added, ...kept], updatedAt: DateTime.now()));
  }

  /// Puts [noteId] in exactly the collections in [collectionIds].
  void setMembership(String noteId, Set<String> collectionIds) {
    final now = DateTime.now();
    var changed = false;
    for (final c in _collections.values.toList()) {
      final want = collectionIds.contains(c.id);
      if (want == c.contains(noteId)) continue;
      _collections[c.id] = (want ? c.withNote(noteId) : c.withoutNote(noteId))
          .copyWith(updatedAt: now);
      changed = true;
    }
    if (changed) _changed();
  }

  void _changed() {
    notifyListeners();
    _prefs.setString(
      _key,
      jsonEncode([for (final c in _collections.values) c.toJson()]),
    );
  }
}
