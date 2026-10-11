import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

/// Inkleaf's local database: one SQLite file with a table per kind of
/// document. Each row holds one note, board or collection as JSON, so a
/// change writes just that row, inside SQLite's crash-safe journal.
///
/// The API is synchronous: rows are small and SQLite writes them in well
/// under a millisecond, so repositories can save straight away.
class AppDatabase {
  AppDatabase._(this._db) {
    _db.execute('PRAGMA journal_mode = WAL');
    for (final table in _tables) {
      _db.execute(
        'CREATE TABLE IF NOT EXISTS $table '
        '(id TEXT NOT NULL PRIMARY KEY, data TEXT NOT NULL) STRICT',
      );
    }
    _db.execute(
      'CREATE TABLE IF NOT EXISTS meta '
      '(key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL) STRICT',
    );
  }

  static late AppDatabase instance;

  static const notes = 'notes';
  static const boards = 'boards';
  static const collections = 'collections';
  static const _tables = [notes, boards, collections];

  /// Meta key for the collections drawer order (a JSON list of ids).
  static const collectionsOrderKey = 'collections_order';

  /// Opens (or creates) `inkleaf.db` in the app's support folder.
  static Future<void> open() async {
    final dir = await getApplicationSupportDirectory();
    openFile('${dir.path}${Platform.pathSeparator}inkleaf.db');
  }

  static void openFile(String path) =>
      instance = AppDatabase._(sqlite3.open(path));

  /// A throwaway database, for tests.
  static void openInMemory() =>
      instance = AppDatabase._(sqlite3.openInMemory());

  final Database _db;

  /// Every document in [table].
  List<Map<String, Object?>> readAll(String table) => [
    for (final row in _db.select('SELECT data FROM $table'))
      (jsonDecode(row['data'] as String) as Map).cast<String, Object?>(),
  ];

  /// Adds or replaces the document with [id].
  void put(String table, String id, Map<String, Object?> json) => _db.execute(
    'INSERT OR REPLACE INTO $table (id, data) VALUES (?, ?)',
    [id, jsonEncode(json)],
  );

  void remove(String table, String id) =>
      _db.execute('DELETE FROM $table WHERE id = ?', [id]);

  String? meta(String key) {
    final rows = _db.select('SELECT value FROM meta WHERE key = ?', [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  void setMeta(String key, String value) => _db.execute(
    'INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)',
    [key, value],
  );

  /// Runs [body] as one transaction: all of its writes land, or none do.
  T transaction<T>(T Function() body) {
    _db.execute('BEGIN');
    try {
      final result = body();
      _db.execute('COMMIT');
      return result;
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Moves data saved by earlier versions (a JSON list per kind in
  /// SharedPreferences) into the database, then removes it from there.
  ///
  /// Runs every launch and does nothing once moved. Rows already in the
  /// database win, and the old keys are only removed after the import has
  /// committed, so an interrupted import is simply repeated next time.
  Future<void> importLegacy(SharedPreferences prefs) async {
    final moved = <String>[];
    transaction(() {
      for (final table in _tables) {
        final raw = prefs.getString(table);
        if (raw == null) continue;
        for (final item in jsonDecode(raw) as List<Object?>) {
          final json = (item! as Map).cast<String, Object?>();
          _db.execute('INSERT OR IGNORE INTO $table (id, data) VALUES (?, ?)', [
            json['id']! as String,
            jsonEncode(json),
          ]);
        }
        moved.add(table);
      }
      final order = prefs.getStringList(collectionsOrderKey);
      if (order != null) {
        if (meta(collectionsOrderKey) == null) {
          setMeta(collectionsOrderKey, jsonEncode(order));
        }
        moved.add(collectionsOrderKey);
      }
    });
    for (final key in moved) {
      await prefs.remove(key);
    }
  }

  void close() => _db.close();
}
