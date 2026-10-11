import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/collection.dart';

/// All collections, kept in memory and saved to [SharedPreferences] as
/// JSON. Listen to it to rebuild when a collection changes.
class CollectionsRepository extends ChangeNotifier {
  CollectionsRepository._(this._prefs, this._collections, this._order);

  static late CollectionsRepository instance;

  static const _key = 'collections';
  static const _orderKey = 'collections_order';

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
    instance = CollectionsRepository._(
      prefs,
      collections,
      prefs.getStringList(_orderKey) ?? [],
    );
  }

  final SharedPreferences _prefs;
  final Map<String, Collection> _collections;

  /// Drawer order, front first. A deleted collection's id stays, so undoing
  /// the delete puts the folder back where it was.
  List<String> _order;

  /// Collections in drawer order. Any missing from the saved order (from
  /// before reordering existed) come first, most recently changed first.
  List<Collection> get collections {
    final rank = {for (var i = 0; i < _order.length; i++) _order[i]: i};
    return _collections.values.toList()..sort((a, b) {
      final ra = rank[a.id], rb = rank[b.id];
      if (ra == null && rb == null) return b.updatedAt.compareTo(a.updatedAt);
      if (ra == null) return -1;
      if (rb == null) return 1;
      return ra.compareTo(rb);
    });
  }

  /// Moves the collection at [from] to [to], in [collections] order.
  void reorder(int from, int to) {
    final ids = [for (final c in collections) c.id];
    if (from == to || from < 0 || from >= ids.length) return;
    ids.insert(to.clamp(0, ids.length - 1), ids.removeAt(from));
    _order = ids;
    _changed();
  }

  Collection? byId(String id) => _collections[id];

  /// Collections containing [noteId].
  List<Collection> containing(String noteId) =>
      collections.where((c) => c.contains(noteId)).toList();

  /// Adds [collection] or replaces the one with the same id.
  void save(Collection collection) {
    // New folders go in at the front of the drawer.
    if (!_order.contains(collection.id)) _order.insert(0, collection.id);
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
    _prefs.setStringList(_orderKey, _order);
  }
}
