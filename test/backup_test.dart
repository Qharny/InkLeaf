import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_note/core/storage/app_database.dart';
import 'package:my_note/core/storage/media_store.dart';
import 'package:my_note/features/backup/data/backup_service.dart';

Map<String, Object?> _note(
  String id,
  String title, {
  String updated = '2026-01-01T00:00:00.000',
  Map<String, Object?>? audio,
  String? scanFile,
}) => {
  'id': id,
  'title': title,
  'createdAt': '2026-01-01T00:00:00.000',
  'updatedAt': updated,
  'audio': ?audio,
  'scanFile': ?scanFile,
};

/// A fresh, empty "device": database and media folders.
void _freshDevice() {
  AppDatabase.openInMemory();
  MediaStore.audio.directory = Directory.systemTemp.createTempSync('bk_audio');
  MediaStore.scans.directory = Directory.systemTemp.createTempSync('bk_scans');
}

void main() {
  setUp(_freshDevice);

  test('export then restore on a new device brings everything back', () {
    File(MediaStore.audio.pathOf('voice_1.m4a')).writeAsStringSync('aac');
    File(MediaStore.scans.pathOf('scan_1.jpg')).writeAsStringSync('jpg');
    AppDatabase.instance
      ..put(
        AppDatabase.notes,
        'n1',
        _note(
          'n1',
          'Voice',
          audio: {'fileName': 'voice_1.m4a', 'durationMs': 900},
        ),
      )
      ..put(
        AppDatabase.notes,
        'n2',
        _note('n2', 'Page', scanFile: 'scan_1.jpg'),
      )
      ..put(AppDatabase.boards, 'b1', {'id': 'b1', 'title': 'Plan'})
      ..put(AppDatabase.collections, 'c1', {'id': 'c1', 'name': 'Work'})
      ..setMeta(AppDatabase.collectionsOrderKey, '["c1"]');

    final zip = BackupService.export(now: DateTime(2026, 10, 11, 16, 20));

    _freshDevice();
    final summary = BackupService.restore(zip);
    expect(summary, (notes: 2, boards: 1, collections: 1, files: 2));
    final db = AppDatabase.instance;
    expect(db.readAll(AppDatabase.notes).map((n) => n['title']).toSet(), {
      'Voice',
      'Page',
    });
    expect(db.meta(AppDatabase.collectionsOrderKey), '["c1"]');
    expect(
      File(MediaStore.audio.pathOf('voice_1.m4a')).readAsStringSync(),
      'aac',
    );
    expect(File(MediaStore.scans.pathOf('scan_1.jpg')).existsSync(), isTrue);
  });

  test('restore keeps whichever copy was edited last', () {
    final db = AppDatabase.instance
      ..put(
        AppDatabase.notes,
        'old',
        _note('old', 'Old here', updated: '2026-01-01T00:00:00.000'),
      )
      ..put(
        AppDatabase.notes,
        'new',
        _note('new', 'Newer here', updated: '2026-05-01T00:00:00.000'),
      );
    final zip = _zip({
      'app': 'inkleaf',
      'format': 1,
      'notes': [
        _note('old', 'Newer in backup', updated: '2026-03-01T00:00:00.000'),
        _note('new', 'Older in backup', updated: '2026-02-01T00:00:00.000'),
        _note('extra', 'Only in backup'),
      ],
    });

    final summary = BackupService.restore(zip);
    expect(summary.notes, 2);
    final titles = {
      for (final n in db.readAll(AppDatabase.notes)) n['id']: n['title'],
    };
    expect(titles, {
      'old': 'Newer in backup',
      'new': 'Newer here',
      'extra': 'Only in backup',
    });
  });

  test('rejects files that are not Inkleaf backups', () {
    expect(() => BackupService.restore([1, 2, 3]), throwsFormatException);
    expect(
      () => BackupService.restore(_zip({'app': 'other'})),
      throwsFormatException,
    );
    expect(
      () => BackupService.restore(_zip({'app': 'inkleaf', 'format': 99})),
      throwsFormatException,
    );
  });

  test('media entries cannot write outside their folder', () {
    final zip = _zip(
      {'app': 'inkleaf', 'format': 1},
      extra: {'audio/../escape.m4a': 'x', 'audio/ok.m4a': 'y'},
    );
    final summary = BackupService.restore(zip);
    expect(summary.files, 1);
    expect(
      File('${MediaStore.audio.directory.parent.path}/escape.m4a').existsSync(),
      isFalse,
    );
  });

  test('backup file name carries the date and time', () {
    expect(
      BackupService.fileName(DateTime(2026, 3, 4, 5, 6)),
      'inkleaf-backup-2026-03-04-0506.zip',
    );
  });
}

List<int> _zip(Map<String, Object?> manifest, {Map<String, String>? extra}) {
  final archive = Archive()
    ..addFile(ArchiveFile.string('backup.json', jsonEncode(manifest)));
  extra?.forEach((name, content) {
    archive.addFile(ArchiveFile.string(name, content));
  });
  return ZipEncoder().encodeBytes(archive);
}
