import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Files that belong to notes, kept in the app's documents folder:
/// recordings in `audio/`, scanned pages in `scans/`.
///
/// Notes store only the file name, because the documents path itself can
/// change between app launches on iOS.
class MediaStore {
  MediaStore._(this.folder, this.prefix, this.extension);

  static final audio = MediaStore._('audio', 'voice', 'm4a');
  static final scans = MediaStore._('scans', 'scan', 'jpg');

  static Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    for (final store in [audio, scans]) {
      store.directory = Directory(
        '${docs.path}${Platform.pathSeparator}${store.folder}',
      );
      await store.directory.create(recursive: true);
    }
  }

  final String folder;
  final String prefix;
  final String extension;
  late Directory directory;

  String pathOf(String fileName) =>
      '${directory.path}${Platform.pathSeparator}$fileName';

  String newFileName() =>
      '${prefix}_${DateTime.now().millisecondsSinceEpoch}.$extension';

  /// Copies [sourcePath] into this store under a new name, and returns it.
  /// Synchronous: callers pass photos already capped in size by the picker.
  String importFile(String sourcePath) {
    final name = newFileName();
    File(sourcePath).copySync(pathOf(name));
    return name;
  }

  /// Deletes a file; one that is already gone is fine.
  Future<void> delete(String fileName) async {
    try {
      await File(pathOf(fileName)).delete();
    } on FileSystemException {
      // Already deleted.
    }
  }
}
