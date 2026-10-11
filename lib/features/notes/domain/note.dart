import 'package:flutter/foundation.dart';

import '../../canvas/domain/board.dart';

var _itemCounter = 0;

/// One line of a note's checklist.
@immutable
class ChecklistItem {
  const ChecklistItem({required this.id, this.text = '', this.done = false});

  factory ChecklistItem.create() => ChecklistItem(
    id:
        '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
        '${(_itemCounter++).toRadixString(36)}',
  );

  final String id;
  final String text;
  final bool done;

  ChecklistItem copyWith({String? text, bool? done}) =>
      ChecklistItem(id: id, text: text ?? this.text, done: done ?? this.done);

  Map<String, Object?> toJson() => {'id': id, 'text': text, 'done': done};

  factory ChecklistItem.fromJson(Map<String, Object?> json) => ChecklistItem(
    id: json['id']! as String,
    text: json['text'] as String? ?? '',
    done: json['done'] as bool? ?? false,
  );
}

/// A voice recording attached to a note.
@immutable
class NoteAudio {
  const NoteAudio({required this.fileName, required this.durationMs});

  /// File name inside `MediaStore.audio.directory`.
  final String fileName;
  final int durationMs;

  Duration get duration => Duration(milliseconds: durationMs);

  Map<String, Object?> toJson() => {
    'fileName': fileName,
    'durationMs': durationMs,
  };

  factory NoteAudio.fromJson(Map<String, Object?> json) => NoteAudio(
    fileName: json['fileName']! as String,
    durationMs: json['durationMs'] as int? ?? 0,
  );
}

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
    this.checklist = const [],
    this.audio,
    this.scanFile,
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

  /// To-do items, in order.
  final List<ChecklistItem> checklist;

  /// A voice recording, if any.
  final NoteAudio? audio;

  /// The scanned page this note was made from: a file name inside
  /// `MediaStore.scans.directory`.
  final String? scanFile;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Set while the note is in the trash.
  final DateTime? deletedAt;

  bool get isEmpty =>
      title.trim().isEmpty &&
      body.trim().isEmpty &&
      sketch.isEmpty &&
      checklist.every((i) => i.text.trim().isEmpty) &&
      audio == null &&
      scanFile == null;
  bool get inTrash => deletedAt != null;

  /// The title, or the first line of the body when there is no title.
  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    final firstLine = body.trim().split('\n').first;
    if (firstLine.isNotEmpty) return firstLine;
    for (final item in checklist) {
      if (item.text.trim().isNotEmpty) return item.text.trim();
    }
    if (audio != null) return 'Voice note';
    if (scanFile != null) return 'Scan';
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
        tags.any((t) => t.contains(q)) ||
        checklist.any((i) => i.text.toLowerCase().contains(q));
  }

  Note copyWith({
    String? title,
    String? body,
    int? color,
    bool? pinned,
    List<String>? tags,
    List<BoardStroke>? sketch,
    List<ChecklistItem>? checklist,
    NoteAudio? Function()? audio,
    String? Function()? scanFile,
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
    checklist: checklist ?? this.checklist,
    audio: audio != null ? audio() : this.audio,
    scanFile: scanFile != null ? scanFile() : this.scanFile,
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
    if (checklist.isNotEmpty)
      'checklist': [for (final i in checklist) i.toJson()],
    if (audio != null) 'audio': audio!.toJson(),
    if (scanFile != null) 'scanFile': scanFile,
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
    checklist: [
      for (final i in json['checklist'] as List<Object?>? ?? const [])
        ChecklistItem.fromJson((i! as Map).cast<String, Object?>()),
    ],
    audio: switch (json['audio']) {
      final Map<Object?, Object?> a => NoteAudio.fromJson(
        a.cast<String, Object?>(),
      ),
      _ => null,
    },
    scanFile: json['scanFile'] as String?,
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
