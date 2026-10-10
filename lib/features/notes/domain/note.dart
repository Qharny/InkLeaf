import 'package:flutter/foundation.dart';

import '../../canvas/domain/board.dart';

/// A text note. Immutable; edits produce a new copy via [copyWith].
@immutable
class Note {
  const Note({
    required this.id,
    this.title = '',
    this.body = '',
    this.color = 0,
    this.pinned = false,
    this.tags = const [],
    this.sketch = const [],
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  /// A fresh, empty note with a unique id.
  factory Note.create({int color = 0}) {
    final now = DateTime.now();
    return Note(
      id: now.microsecondsSinceEpoch.toRadixString(36),
      color: color,
      createdAt: now,
      updatedAt: now,
    );
  }

  final String id;
  final String title;
  final String body;

  /// Index into `AppColors.notes`.
  final int color;
  final bool pinned;
  final List<String> tags;

  /// A hand drawing, in the sketch pad's coordinates.
  final List<BoardStroke> sketch;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Set while the note is in the trash.
  final DateTime? deletedAt;

  bool get isEmpty =>
      title.trim().isEmpty && body.trim().isEmpty && sketch.isEmpty;
  bool get inTrash => deletedAt != null;

  /// The title, or the first line of the body when there is no title.
  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    final firstLine = body.trim().split('\n').first;
    if (firstLine.isNotEmpty) return firstLine;
    return sketch.isEmpty ? 'Untitled' : 'Sketch';
  }

  /// Body text to preview under [displayTitle], without repeating it.
  String get preview {
    final text = body.trim();
    if (title.trim().isNotEmpty) return text;
    final newline = text.indexOf('\n');
    return newline == -1 ? '' : text.substring(newline + 1).trim();
  }

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return title.toLowerCase().contains(q) ||
        body.toLowerCase().contains(q) ||
        tags.any((t) => t.contains(q));
  }

  Note copyWith({
    String? title,
    String? body,
    int? color,
    bool? pinned,
    List<String>? tags,
    List<BoardStroke>? sketch,
    DateTime? updatedAt,
    DateTime? Function()? deletedAt,
  }) => Note(
    id: id,
    title: title ?? this.title,
    body: body ?? this.body,
    color: color ?? this.color,
    pinned: pinned ?? this.pinned,
    tags: tags ?? this.tags,
    sketch: sketch ?? this.sketch,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt != null ? deletedAt() : this.deletedAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'color': color,
    'pinned': pinned,
    'tags': tags,
    if (sketch.isNotEmpty) 'sketch': [for (final s in sketch) s.toJson()],
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory Note.fromJson(Map<String, Object?> json) => Note(
    id: json['id']! as String,
    title: json['title'] as String? ?? '',
    body: json['body'] as String? ?? '',
    color: json['color'] as int? ?? 0,
    pinned: json['pinned'] as bool? ?? false,
    tags: (json['tags'] as List<Object?>? ?? const []).cast<String>(),
    sketch: [
      for (final s in json['sketch'] as List<Object?>? ?? const [])
        BoardStroke.fromJson((s! as Map).cast<String, Object?>()),
    ],
    createdAt: DateTime.parse(json['createdAt']! as String),
    updatedAt: DateTime.parse(json['updatedAt']! as String),
    deletedAt: switch (json['deletedAt']) {
      final String s => DateTime.parse(s),
      _ => null,
    },
  );
}

/// Orderings for note lists.
enum NoteSort {
  edited('Last edited'),
  created('Date created'),
  title('Title');

  const NoteSort(this.label);

  final String label;

  static NoteSort parse(String? value) =>
      NoteSort.values.asNameMap()[value] ?? NoteSort.edited;

  int compare(Note a, Note b) => switch (this) {
    NoteSort.edited => b.updatedAt.compareTo(a.updatedAt),
    NoteSort.created => b.createdAt.compareTo(a.createdAt),
    NoteSort.title => a.displayTitle.toLowerCase().compareTo(
      b.displayTitle.toLowerCase(),
    ),
  };
}
