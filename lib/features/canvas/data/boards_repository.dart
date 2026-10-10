import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/board.dart';

/// All canvases, kept in memory and saved to [SharedPreferences] as JSON.
///
/// Listen to it to rebuild when a board changes.
class BoardsRepository extends ChangeNotifier {
  BoardsRepository._(this._prefs, this._boards);

  static late BoardsRepository instance;

  static const _key = 'boards';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final boards = <String, Board>{};
    if (raw != null) {
      for (final json in (jsonDecode(raw) as List<Object?>)) {
        final board = Board.fromJson((json! as Map).cast<String, Object?>());
        boards[board.id] = board;
      }
    }
    instance = BoardsRepository._(prefs, boards);
  }

  final SharedPreferences _prefs;
  final Map<String, Board> _boards;

  /// Boards, most recently edited first.
  List<Board> get boards =>
      _boards.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  Board? byId(String id) => _boards[id];

  /// Adds [board] or replaces the board with the same id.
  void save(Board board) {
    _boards[board.id] = board;
    _changed();
  }

  void delete(String id) {
    if (_boards.remove(id) != null) _changed();
  }

  void _changed() {
    notifyListeners();
    _prefs.setString(
      _key,
      jsonEncode([for (final b in _boards.values) b.toJson()]),
    );
  }
}
