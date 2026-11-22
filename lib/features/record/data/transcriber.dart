import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

/// The download was stopped before it finished.
class DownloadCancelled implements Exception {
  const DownloadCancelled();
}

/// Turns a saved recording into text, on the phone. An interface so tests
/// can swap in a fake through [create]; the app runs Whisper.
///
/// The speech model is too big to ship inside the app, so it's downloaded
/// once, when the user first asks for a transcript. Audio never leaves the
/// device: only the model file comes in.
abstract class Transcriber {
  static Transcriber Function() create = _WhisperTranscriber.new;

  /// The model's download size, for the confirmation dialog.
  static const modelSize = '142 MB';

  /// Whether the speech model is on the phone.
  Future<bool> modelReady();

  /// Downloads the speech model, reporting 0–1 progress (null while the
  /// size is unknown). Throws [DownloadCancelled] once [cancelled] returns
  /// true, and leaves no partial file behind either way.
  Future<void> downloadModel({
    required ValueChanged<double?> onProgress,
    required bool Function() cancelled,
  });

  /// Deletes the speech model to free space.
  Future<void> deleteModel();

  /// The words spoken in the recording at [audioPath], reporting 0–1
  /// progress. Runs off the UI thread.
  Future<String> transcribe(
    String audioPath, {
    required ValueChanged<double> onProgress,
  });
}

class _WhisperTranscriber implements Transcriber {
  /// "base" is the smallest multilingual model that's accurate enough to
  /// be worth editing rather than retyping.
  static const _model = WhisperModel.base;

  final _controller = WhisperController();

  Future<File> _modelFile() async => File(await _controller.getPath(_model));

  @override
  Future<bool> modelReady() async => (await _modelFile()).exists();

  @override
  Future<void> downloadModel({
    required ValueChanged<double?> onProgress,
    required bool Function() cancelled,
  }) async {
    final target = await _modelFile();
    if (await target.exists()) return;
    final part = File('${target.path}.part');
    final client = HttpClient();
    IOSink? sink;
    try {
      final response = await (await client.getUrl(_model.modelUri)).close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Download failed (${response.statusCode})');
      }
      final total = response.contentLength;
      var received = 0;
      sink = part.openWrite();
      onProgress(total > 0 ? 0 : null);
      await for (final chunk in response) {
        if (cancelled()) throw const DownloadCancelled();
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress(received / total);
      }
      await sink.close();
      sink = null;
      if (total > 0 && await part.length() != total) {
        throw const HttpException('Download ended early');
      }
      await part.rename(target.path);
    } finally {
      await sink?.close();
      client.close(force: true);
      if (await part.exists()) await part.delete();
    }
  }

  @override
  Future<void> deleteModel() async {
    final file = await _modelFile();
    if (await file.exists()) await file.delete();
  }

  @override
  Future<String> transcribe(
    String audioPath, {
    required ValueChanged<double> onProgress,
  }) async {
    final model = await _modelFile();
    try {
      final response = await const Whisper(model: _model).transcribe(
        transcribeRequest: TranscribeRequest(
          audio: audioPath,
          language: _language(),
          isNoTimestamps: true,
          threads: Platform.numberOfProcessors.clamp(1, 4),
          // Keeps coughs and silence from coming out as made-up words, and
          // stops a misheard phrase repeating through a long recording.
          suppressNonSpeechTokens: true,
          maxContext: 0,
        ),
        modelPath: model.path,
        onProgress: (percent) => onProgress(percent / 100),
      );
      return response.text;
    } finally {
      // Whisper reads a 16 kHz WAV it converts next to the recording.
      final wav = File('$audioPath.wav');
      if (await wav.exists()) await wav.delete();
    }
  }

  /// Which language to listen for. Android's Whisper build detects it from
  /// the audio; the iOS build can't, so it assumes the phone's language.
  static String _language() {
    if (!Platform.isIOS) return 'auto';
    return PlatformDispatcher.instance.locale.languageCode;
  }
}
