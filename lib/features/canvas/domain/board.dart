import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Width and height of every board, in board units (logical pixels at 1x).
const boardSize = 4000.0;

var _idCounter = 0;

/// A unique id for boards and the things on them.
String newBoardId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
    '${(_idCounter++).toRadixString(36)}';

enum BoardCardKind { sticky, note }

/// A card on a board: a sticky with its own text, or a link to a note.
@immutable
class BoardCard {
  const BoardCard({
    required this.id,
    required this.kind,
    this.text = '',
    this.noteId,
    this.color = 0,
    required this.x,
    required this.y,
    this.width = 180,
    this.height = 140,
  });

  static const minWidth = 120.0;
  static const minHeight = 80.0;
  static const maxSide = 640.0;

  final String id;
  final BoardCardKind kind;

  /// Sticky text. Unused for note cards.
  final String text;

  /// The linked note, for [BoardCardKind.note].
  final String? noteId;

  /// Index into `AppColors.notes`.
  final int color;
  final double x;
  final double y;
  final double width;
  final double height;

  Rect get rect => Rect.fromLTWH(x, y, width, height);

  BoardCard copyWith({
    String? text,
    int? color,
    double? x,
    double? y,
    double? width,
    double? height,
  }) => BoardCard(
    id: id,
    kind: kind,
    text: text ?? this.text,
    noteId: noteId,
    color: color ?? this.color,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'text': text,
    'noteId': noteId,
    'color': color,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };

  factory BoardCard.fromJson(Map<String, Object?> json) => BoardCard(
    id: json['id']! as String,
    kind:
        BoardCardKind.values.asNameMap()[json['kind']] ?? BoardCardKind.sticky,
    text: json['text'] as String? ?? '',
    noteId: json['noteId'] as String?,
    color: json['color'] as int? ?? 0,
    x: (json['x']! as num).toDouble(),
    y: (json['y']! as num).toDouble(),
    width: (json['width'] as num? ?? 180).toDouble(),
    height: (json['height'] as num? ?? 140).toDouble(),
  );
}

/// An arrow from one card to another.
@immutable
class BoardLink {
  const BoardLink({required this.id, required this.from, required this.to});

  final String id;
  final String from;
  final String to;

  Map<String, Object?> toJson() => {'id': id, 'from': from, 'to': to};

  factory BoardLink.fromJson(Map<String, Object?> json) => BoardLink(
    id: json['id']! as String,
    from: json['from']! as String,
    to: json['to']! as String,
  );
}

/// A freehand pen stroke.
@immutable
class BoardStroke {
  const BoardStroke({
    required this.id,
    required this.points,
    required this.color,
    required this.width,
  });

  final String id;
  final List<Offset> points;

  /// ARGB color value.
  final int color;
  final double width;

  Rect get bounds {
    var rect = Rect.fromPoints(points.first, points.first);
    for (final p in points.skip(1)) {
      rect = rect.expandToInclude(Rect.fromPoints(p, p));
    }
    return rect.inflate(width / 2);
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'color': color,
    'width': width,
    // Flat [x1, y1, x2, y2, ...], rounded to keep saved boards small.
    'points': [
      for (final p in points) ...[
        (p.dx * 10).roundToDouble() / 10,
        (p.dy * 10).roundToDouble() / 10,
      ],
    ],
  };

  factory BoardStroke.fromJson(Map<String, Object?> json) {
    final flat = (json['points']! as List<Object?>).cast<num>();
    return BoardStroke(
      id: json['id']! as String,
      color: json['color']! as int,
      width: (json['width']! as num).toDouble(),
      points: [
        for (var i = 0; i + 1 < flat.length; i += 2)
          Offset(flat[i].toDouble(), flat[i + 1].toDouble()),
      ],
    );
  }
}

/// A canvas: cards, the arrows between them, and freehand drawing.
///
/// Immutable; every edit returns a new board, which makes undo a stack of
/// previous boards.
@immutable
class Board {
  const Board({
    required this.id,
    this.title = defaultTitle,
    this.cards = const [],
    this.links = const [],
    this.strokes = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Board.create() {
    final now = DateTime.now();
    return Board(id: newBoardId(), createdAt: now, updatedAt: now);
  }

  static const defaultTitle = 'Untitled canvas';

  final String id;
  final String title;

  /// Cards in paint order; the last one is on top.
  final List<BoardCard> cards;
  final List<BoardLink> links;
  final List<BoardStroke> strokes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isEmpty => cards.isEmpty && strokes.isEmpty;

  /// The area covering every card and stroke, or null for an empty board.
  Rect? get contentBounds {
    Rect? bounds;
    for (final rect in [
      for (final c in cards) c.rect,
      for (final s in strokes) s.bounds,
    ]) {
      bounds = bounds?.expandToInclude(rect) ?? rect;
    }
    return bounds;
  }

  BoardCard? card(String id) {
    for (final c in cards) {
      if (c.id == id) return c;
    }
    return null;
  }

  Board copyWith({
    String? title,
    List<BoardCard>? cards,
    List<BoardLink>? links,
    List<BoardStroke>? strokes,
    DateTime? updatedAt,
  }) => Board(
    id: id,
    title: title ?? this.title,
    cards: cards ?? this.cards,
    links: links ?? this.links,
    strokes: strokes ?? this.strokes,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Board addCard(BoardCard card) => copyWith(cards: [...cards, card]);

  /// Replaces the card with the same id, keeping its place in paint order.
  Board updateCard(BoardCard card) =>
      copyWith(cards: [for (final c in cards) c.id == card.id ? card : c]);

  Board bringToFront(String id) {
    final c = card(id);
    if (c == null || cards.last.id == id) return this;
    return copyWith(cards: [...cards.where((c) => c.id != id), c]);
  }

  /// Removes the card and every arrow touching it.
  Board removeCard(String id) => copyWith(
    cards: cards.where((c) => c.id != id).toList(),
    links: links.where((l) => l.from != id && l.to != id).toList(),
  );

  /// Adds an arrow, unless it would point a card at itself or the two cards
  /// are already connected.
  Board addLink(String from, String to) {
    final exists = links.any(
      (l) => (l.from == from && l.to == to) || (l.from == to && l.to == from),
    );
    if (from == to || exists || card(from) == null || card(to) == null) {
      return this;
    }
    return copyWith(
      links: [
        ...links,
        BoardLink(id: newBoardId(), from: from, to: to),
      ],
    );
  }

  Board removeLink(String id) =>
      copyWith(links: links.where((l) => l.id != id).toList());

  Board addStroke(BoardStroke stroke) =>
      copyWith(strokes: [...strokes, stroke]);

  Board removeStrokes(Set<String> ids) =>
      copyWith(strokes: strokes.where((s) => !ids.contains(s.id)).toList());

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'cards': [for (final c in cards) c.toJson()],
    'links': [for (final l in links) l.toJson()],
    'strokes': [for (final s in strokes) s.toJson()],
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Board.fromJson(Map<String, Object?> json) {
    List<Map<String, Object?>> list(String key) => [
      for (final item in json[key] as List<Object?>? ?? const [])
        (item! as Map).cast<String, Object?>(),
    ];
    return Board(
      id: json['id']! as String,
      title: json['title'] as String? ?? defaultTitle,
      cards: list('cards').map(BoardCard.fromJson).toList(),
      links: list('links').map(BoardLink.fromJson).toList(),
      strokes: list('strokes').map(BoardStroke.fromJson).toList(),
      createdAt: DateTime.parse(json['createdAt']! as String),
      updatedAt: DateTime.parse(json['updatedAt']! as String),
    );
  }
}
