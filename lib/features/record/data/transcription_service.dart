import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/storage/media_store.dart';
import '../../notes/data/notes_repository.dart';
import '../domain/transcript.dart';
import 'transcriber.dart';

enum TranscriptOutcome {
  /// The words were added to the note.
  done,

  /// The recording had no speech in it.
  noSpeech,

  /// The note, or its recording file, is gone.
  missingAudio,

  /// Whisper failed.
  failed,
}

/// The result of one transcription, handed to the editor showing the note.
class TranscriptResult {
  const TranscriptResult(this.outcome, [this.text = '']);

  final TranscriptOutcome outcome;

  /// The cleaned-up words, when [outcome] is [TranscriptOutcome.done].
  final String text;
}

/// Transcribes voice notes in the background, one at a time (each run
/// loads the whole speech model), and adds the words to the note's body.
///
/// The editor showing a note [attach]es to it while open: it gets the
/// words to insert itself, so its own unsaved typing isn't overwritten.
/// Otherwise the note is updated in the [NotesRepository] directly.
class TranscriptionService extends ChangeNotifier {
  TranscriptionService({Transcriber? transcriber})
    : _transcriber = transcriber ?? Transcriber.create();

  static TranscriptionService instance = TranscriptionService();

  final Transcriber _transcriber;

  /// Jobs by note id: progress from 0 to 1, or null while waiting a turn.
  final _jobs = <String, double?>{};
  final _receivers = <String, ValueChanged<TranscriptResult>>{};
  Future<void> _queue = Future.value();

  Transcriber get transcriber => _transcriber;

  bool isTranscribing(String noteId) => _jobs.containsKey(noteId);

  /// 0–1 while [noteId]'s recording is being transcribed, null while it
  /// waits for another one to finish (or isn't queued at all).
  double? progressOf(String noteId) => _jobs[noteId];

  /// Sends [noteId]'s transcripts to [onResult] instead of saving them.
  void attach(String noteId, ValueChanged<TranscriptResult> onResult) =>
      _receivers[noteId] = onResult;

  void detach(String noteId, ValueChanged<TranscriptResult> onResult) {
    if (_receivers[noteId] == onResult) _receivers.remove(noteId);
  }

  /// Queues [noteId]'s recording; completes once its words are added.
  /// Asking again while it's queued just waits for the same job.
  Future<TranscriptOutcome> transcribe(String noteId) {
    if (isTranscribing(noteId)) return _queue.then((_) => _outcomeOf(noteId));
    _jobs[noteId] = null;
    notifyListeners();
    final job = _queue.then((_) => _run(noteId));
    _queue = job.then((_) {}, onError: (_) {});
    return job;
  }

  final _finished = <String, TranscriptOutcome>{};

  TranscriptOutcome _outcomeOf(String noteId) =>
      _finished[noteId] ?? TranscriptOutcome.failed;

  Future<TranscriptOutcome> _run(String noteId) async {
    final outcome = await _transcribeNote(noteId);
    _jobs.remove(noteId);
    _finished[noteId] = outcome;
    notifyListeners();
    return outcome;
  }

  Future<TranscriptOutcome> _transcribeNote(String noteId) async {
    final repo = NotesRepository.instance;
    final audio = repo.byId(noteId)?.audio;
    if (audio == null) return _deliver(noteId, TranscriptOutcome.missingAudio);
    final path = MediaStore.audio.pathOf(audio.fileName);
    if (!File(path).existsSync()) {
      return _deliver(noteId, TranscriptOutcome.missingAudio);
    }

    _jobs[noteId] = 0;
    notifyListeners();
    final String text;
    try {
      text = cleanTranscript(
        await _transcriber.transcribe(
          path,
          onProgress: (p) {
            if (!_jobs.containsKey(noteId)) return;
            _jobs[noteId] = p.clamp(0.0, 1.0);
            notifyListeners();
          },
        ),
      );
    } on Object catch (e) {
      debugPrint('Transcription failed: $e');
      return _deliver(noteId, TranscriptOutcome.failed);
    }
    if (text.isEmpty) return _deliver(noteId, TranscriptOutcome.noSpeech);

    final receiver = _receivers[noteId];
    if (receiver != null) {
      receiver(TranscriptResult(TranscriptOutcome.done, text));
      return TranscriptOutcome.done;
    }
    // The note may have changed, lost its recording or been deleted while
    // Whisper worked; only add the words to the recording they came from.
    final latest = repo.byId(noteId);
    final latestAudio = latest?.audio;
    if (latest == null || latestAudio?.fileName != audio.fileName) {
      return TranscriptOutcome.missingAudio;
    }
    repo.save(
      latest.copyWith(
        body: appendTranscript(latest.body, text),
        audio: () => latestAudio!.copyWith(transcribed: true),
        updatedAt: DateTime.now(),
      ),
    );
    return TranscriptOutcome.done;
  }

  TranscriptOutcome _deliver(String noteId, TranscriptOutcome outcome) {
    _receivers[noteId]?.call(TranscriptResult(outcome));
    return outcome;
  }
}
