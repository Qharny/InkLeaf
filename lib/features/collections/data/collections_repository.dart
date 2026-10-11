import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/storage/app_database.dart';
import '../domain/collection.dart';

/// All collections, kept in memory and saved to the [AppDatabase], one row
/// per collection. Listen to it to rebuild when a collection changes.
class CollectionsRepository extends ChangeNotifier {
  CollectionsRepository._(this._db, this._collections, this._order);

  static late CollectionsRepository instance;

  static Future<void> init() async {
    final db = AppDatabase.instance;
    instance = CollectionsRepository._(db, _load(db), _loadOrder(db));
  }

  static Map<String, Collection> _load(AppDatabase db) => {
    for (final json in db.readAll(AppDatabase.collections))
      json['id']! as String: Collection.fromJson(json),
  };

  static List<String> _loadOrder(AppDatabase db) {
    final order = db.meta(AppDatabase.collectionsOrderKey);
    return order == null
        ? []
        : (jsonDecode(order) as List<Object?>).cast<String>();
  }

  /// Re-reads every collection and the drawer order, e.g. after restoring
  /// a backup.
  void reload() {
    _collections
      ..clear()
      ..addAll(_load(_db));
    _order = _loadOrder(_db);
    notifyListeners();
  }

  final AppDatabase _db;
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
    _saveOrder();
    notifyListeners();
  }

  Collection? byId(String id) => _collections[id];

  /// Collections containing [noteId].
  List<Collection> containing(String noteId) =>
      collections.where((c) => c.contains(noteId)).toList();

  /// Adds [collection] or replaces the one with the same id.
  void save(Collection collection) {
    // New folders go in at the front of the drawer.
    final isNew = !_order.contains(collection.id);
    if (isNew) _order.insert(0, collection.id);
    _db.transaction(() {
      _db.put(AppDatabase.collections, collection.id, collection.toJson());
      if (isNew) _saveOrder();
    });
    _collections[collection.id] = collection;
    notifyListeners();
  }

  /// Removes the collection. Its notes are untouched.
  void delete(String id) {
    if (!_collections.containsKey(id)) return;
    _db.remove(AppDatabase.collections, id);
    _collections.remove(id);
    notifyListeners();
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
    final changed = [
      for (final c in _collections.values)
        if (collectionIds.contains(c.id) != c.contains(noteId))
          (collectionIds.contains(c.id)
                  ? c.withNote(noteId)
                  : c.withoutNote(noteId))
              .copyWith(updatedAt: now),
    ];
    if (changed.isEmpty) return;
    _db.transaction(() {
      for (final c in changed) {
        _db.put(AppDatabase.collections, c.id, c.toJson());
      }
    });
    for (final c in changed) {
      _collections[c.id] = c;
    }
    notifyListeners();
  }

  void _saveOrder() =>
      _db.setMeta(AppDatabase.collectionsOrderKey, jsonEncode(_order));
}
