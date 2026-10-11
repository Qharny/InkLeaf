import 'package:flutter/foundation.dart';

import '../../../core/storage/app_database.dart';
import '../domain/board.dart';

/// All canvases, kept in memory and saved to the [AppDatabase], one row per
/// board. Listen to it to rebuild when a board changes.
class BoardsRepository extends ChangeNotifier {
  BoardsRepository._(this._db, this._boards);

  static late BoardsRepository instance;

  static Future<void> init() async {
    final db = AppDatabase.instance;
    instance = BoardsRepository._(db, _load(db));
  }

  static Map<String, Board> _load(AppDatabase db) => {
    for (final json in db.readAll(AppDatabase.boards))
      json['id']! as String: Board.fromJson(json),
  };

  /// Re-reads every board, e.g. after restoring a backup.
  void reload() {
    _boards
      ..clear()
      ..addAll(_load(_db));
    notifyListeners();
  }

  final AppDatabase _db;
  final Map<String, Board> _boards;

  /// Boards, most recently edited first.
  List<Board> get boards =>
      _boards.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  Board? byId(String id) => _boards[id];

  /// Adds [board] or replaces the board with the same id.
  void save(Board board) {
    _db.put(AppDatabase.boards, board.id, board.toJson());
    _boards[board.id] = board;
    notifyListeners();
  }

  void delete(String id) {
    if (!_boards.containsKey(id)) return;
    _db.remove(AppDatabase.boards, id);
    _boards.remove(id);
    notifyListeners();
  }
}
