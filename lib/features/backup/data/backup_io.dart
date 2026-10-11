import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Hands a backup to the system (share sheet: save to Files, Drive, email…)
/// and picks one to restore. An interface so tests can swap in a fake
/// through [create].
abstract class BackupIo {
  static BackupIo Function() create = _PlatformBackupIo.new;

  /// Offers [bytes] as a file called [fileName].
  Future<void> share(Uint8List bytes, String fileName);

  /// The chosen backup's bytes, or null if the user backed out.
  Future<Uint8List?> pick();
}

class _PlatformBackupIo implements BackupIo {
  @override
  Future<void> share(Uint8List bytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/zip')],
        subject: 'Inkleaf backup',
      ),
    );
  }

  @override
  Future<Uint8List?> pick() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (files.isEmpty) return null;
    return files.first.readAsBytes();
  }
}
