import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/storage/media_store.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/domain/note.dart';

/// Something another app shared with Inkleaf.
typedef SharedItem = ({SharedKind kind, String value});

enum SharedKind { text, image, other }

/// Delivers what other apps share with Inkleaf. An interface so tests can
/// swap in a fake through [create]; the app uses `receive_sharing_intent`.
abstract class ShareReceiver {
  static ShareReceiver Function() create = _PluginShareReceiver.new;

  /// What was shared while the app was closed (it launched to receive it).
  Future<List<SharedItem>> initial();

  /// Shares arriving while the app is running.
  Stream<List<SharedItem>> stream();

  /// Marks the launch share as handled, so it isn't delivered again.
  Future<void> reset();
}

class _PluginShareReceiver implements ShareReceiver {
  final _plugin = ReceiveSharingIntent.instance;

  // Text and links arrive with the text itself in `path`.
  static List<SharedItem> _convert(List<SharedMediaFile> files) => [
    for (final f in files)
      (
        kind: switch (f.type) {
          SharedMediaType.text || SharedMediaType.url => SharedKind.text,
          SharedMediaType.image => SharedKind.image,
          _ => SharedKind.other,
        },
        value: f.path,
      ),
  ];

  @override
  Future<List<SharedItem>> initial() async =>
      _convert(await _plugin.getInitialMedia());

  @override
  Stream<List<SharedItem>> stream() => _plugin.getMediaStream().map(_convert);

  @override
  Future<void> reset() async => _plugin.reset();
}

/// Turns shares from other apps into notes.
///
/// The new note's id lands in [pendingNote]; the home screen opens it and
/// clears it. Going through home means a share that launched the app waits
/// for the splash (and onboarding) to finish first.
class ShareInbox {
  ShareInbox._();

  static final instance = ShareInbox._();

  final pendingNote = ValueNotifier<String?>(null);
  StreamSubscription<List<SharedItem>>? _sub;

  Future<void> start() async {
    try {
      final receiver = ShareReceiver.create();
      _sub ??= receiver.stream().listen(receive, onError: (Object _) {});
      receive(await receiver.initial());
      await receiver.reset();
    } on Exception {
      // This platform doesn't support sharing into the app.
    }
  }

  /// Makes a note from [items]: text and links become the body, and the
  /// first image is kept as the note's photo. Returns the note's id, or
  /// null if there was nothing usable.
  String? receive(List<SharedItem> items) {
    final text = [
      for (final item in items)
        if (item.kind == SharedKind.text && item.value.trim().isNotEmpty)
          item.value.trim(),
    ].join('\n\n');

    String? photo;
    for (final item in items.where((i) => i.kind == SharedKind.image)) {
      if (!File(item.value).existsSync()) continue;
      photo = MediaStore.scans.importFile(item.value);
      break;
    }
    if (text.isEmpty && photo == null) return null;

    final repo = NotesRepository.instance;
    final note = Note.create(color: repo.notes.length % AppColors.notes.length)
        .copyWith(body: text, scanFile: () => photo);
    repo.save(note);
    pendingNote.value = note.id;
    return note.id;
  }
}
