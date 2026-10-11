import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Where voice recordings live: `<app documents>/audio/`.
///
/// Notes store only the file name, because the documents path itself can
/// change between app launches on iOS.
abstract final class AudioStore {
  static late Directory directory;

  static Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    directory = Directory('${docs.path}${Platform.pathSeparator}audio');
    await directory.create(recursive: true);
  }

  static String pathOf(String fileName) =>
      '${directory.path}${Platform.pathSeparator}$fileName';

  static String newFileName() =>
      'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

  /// Deletes a recording; a file that is already gone is fine.
  static Future<void> delete(String fileName) async {
    try {
      await File(pathOf(fileName)).delete();
    } on FileSystemException {
      // Already deleted.
    }
  }
}
