import 'package:flutter/foundation.dart';

/// A named notebook grouping notes. A note can be in any number of
/// collections; removing it from one never deletes the note.
@immutable
class Collection {
  const Collection({
    required this.id,
    required this.name,
    this.description = '',
    this.cover = 0,
    this.noteIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Collection.create({
    required String name,
    String description = '',
    int cover = 0,
  }) {
    final now = DateTime.now();
    return Collection(
      id: 'c${now.microsecondsSinceEpoch.toRadixString(36)}',
      name: name,
      description: description,
      cover: cover,
      createdAt: now,
      updatedAt: now,
    );
  }

  final String id;
  final String name;
  final String description;

  /// Index into `AppColors.covers`.
  final int cover;

  /// Notes in this collection, most recently added first.
  final List<String> noteIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool contains(String noteId) => noteIds.contains(noteId);

  Collection copyWith({
    String? name,
    String? description,
    int? cover,
    List<String>? noteIds,
    DateTime? updatedAt,
  }) => Collection(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    cover: cover ?? this.cover,
    noteIds: noteIds ?? this.noteIds,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Collection withNote(String noteId) =>
      contains(noteId) ? this : copyWith(noteIds: [noteId, ...noteIds]);

  Collection withoutNote(String noteId) =>
      copyWith(noteIds: noteIds.where((id) => id != noteId).toList());

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'cover': cover,
    'noteIds': noteIds,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Collection.fromJson(Map<String, Object?> json) => Collection(
    id: json['id']! as String,
    name: json['name'] as String? ?? 'Untitled',
    description: json['description'] as String? ?? '',
    cover: json['cover'] as int? ?? 0,
    noteIds: (json['noteIds'] as List<Object?>? ?? const []).cast<String>(),
    createdAt: DateTime.parse(json['createdAt']! as String),
    updatedAt: DateTime.parse(json['updatedAt']! as String),
  );
}
