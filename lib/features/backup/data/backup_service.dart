import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../../core/storage/app_database.dart';
import '../../../core/storage/media_store.dart';

/// What a restore brought in.
typedef RestoreSummary = ({int notes, int boards, int collections, int files});

/// Packs everything Inkleaf stores into one zip, and merges such a zip back
/// in.
///
/// The zip holds `backup.json` (every note, board and collection, plus the
/// drawer order) and the media files under `audio/` and `scans/`.
abstract final class BackupService {
  static const _manifest = 'backup.json';
  static const _format = 1;
  static const _tables = [
    AppDatabase.notes,
    AppDatabase.boards,
    AppDatabase.collections,
  ];

  /// e.g. `inkleaf-backup-2026-10-11-1620.zip`.
  static String fileName(DateTime now) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'inkleaf-backup-${now.year}-${two(now.month)}-${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}.zip';
  }

  /// The whole notebook as zip bytes.
  static Uint8List export({DateTime? now}) {
    final db = AppDatabase.instance;
    final docs = {for (final t in _tables) t: db.readAll(t)};
    final order = db.meta(AppDatabase.collectionsOrderKey);
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          _manifest,
          jsonEncode({
            'app': 'inkleaf',
            'format': _format,
            'exportedAt': (now ?? DateTime.now()).toIso8601String(),
            for (final t in _tables) t: docs[t],
            'collectionsOrder': order == null ? <String>[] : jsonDecode(order),
          }),
        ),
      );

    void addMedia(MediaStore store, String? fileName) {
      if (fileName == null) return;
      final file = File(store.pathOf(fileName));
      if (!file.existsSync()) return;
      final bytes = file.readAsBytesSync();
      // Audio and photos are already compressed; storing them is faster.
      archive.addFile(
        ArchiveFile.noCompress(
          '${store.folder}/$fileName',
          bytes.length,
          bytes,
        ),
      );
    }

    for (final note in docs[AppDatabase.notes]!) {
      addMedia(
        MediaStore.audio,
        (note['audio'] as Map<String, Object?>?)?['fileName'] as String?,
      );
      addMedia(MediaStore.scans, note['scanFile'] as String?);
    }
    return ZipEncoder().encodeBytes(archive);
  }

  /// Merges the backup in [zip] into this device.
  ///
  /// Nothing is deleted: documents missing here are added, and one that
  /// exists on both sides is replaced only when the backup's copy was
  /// edited more recently. Media files are added when missing.
  ///
  /// Throws a [FormatException] if [zip] is not an Inkleaf backup, or comes
  /// from a newer version of the app.
  static RestoreSummary restore(List<int> zip) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zip);
    } on Object {
      throw const FormatException('Not a zip file');
    }
    final manifestFile = archive.findFile(_manifest);
    if (manifestFile == null) {
      throw const FormatException('Not an Inkleaf backup');
    }
    final manifest = jsonDecode(utf8.decode(manifestFile.content));
    if (manifest is! Map || manifest['app'] != 'inkleaf') {
      throw const FormatException('Not an Inkleaf backup');
    }
    if ((manifest['format'] as int? ?? 0) > _format) {
      throw const FormatException('Made by a newer version of Inkleaf');
    }

    // Files first, so restored notes never point at a missing recording.
    var files = 0;
    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      for (final store in [MediaStore.audio, MediaStore.scans]) {
        final prefix = '${store.folder}/';
        if (!entry.name.startsWith(prefix)) continue;
        final name = entry.name.substring(prefix.length);
        // Only plain file names: never let an entry write outside the folder.
        if (name.isEmpty || name.contains(RegExp(r'[/\\]')) || name == '..') {
          continue;
        }
        final target = File(store.pathOf(name));
        if (target.existsSync()) continue;
        target.writeAsBytesSync(entry.content);
        files++;
      }
    }

    final db = AppDatabase.instance;
    final counts = <String, int>{};
    db.transaction(() {
      for (final table in _tables) {
        final here = {
          for (final doc in db.readAll(table))
            doc['id'] as String: doc['updatedAt'] as String?,
        };
        var added = 0;
        for (final item in manifest[table] as List<Object?>? ?? const []) {
          if (item is! Map) continue;
          final doc = item.cast<String, Object?>();
          final id = doc['id'];
          if (id is! String) continue;
          if (here.containsKey(id) && !_isNewer(doc['updatedAt'], here[id])) {
            continue;
          }
          db.put(table, id, doc);
          added++;
        }
        counts[table] = added;
      }

      // Folders not in this drawer yet go at the back, in backup order.
      final current = db.meta(AppDatabase.collectionsOrderKey);
      final order = current == null
          ? <String>[]
          : (jsonDecode(current) as List<Object?>).cast<String>();
      final incoming = (manifest['collectionsOrder'] as List<Object?>? ?? [])
          .whereType<String>()
          .where((id) => !order.contains(id));
      if (incoming.isNotEmpty) {
        db.setMeta(
          AppDatabase.collectionsOrderKey,
          jsonEncode([...order, ...incoming]),
        );
      }
    });

    return (
      notes: counts[AppDatabase.notes]!,
      boards: counts[AppDatabase.boards]!,
      collections: counts[AppDatabase.collections]!,
      files: files,
    );
  }

  /// Whether ISO timestamp [a] is later than [b] (a missing [b] loses).
  static bool _isNewer(Object? a, String? b) {
    final ta = a is String ? DateTime.tryParse(a) : null;
    final tb = b == null ? null : DateTime.tryParse(b);
    if (ta == null) return false;
    return tb == null || ta.isAfter(tb);
  }
}
