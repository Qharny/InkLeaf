import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

typedef TranscriptCallback =
    void Function(String words, {required bool isFinal});

/// Turns spoken audio into text on-device while recording.
///
/// An interface so tests can swap in a fake through [create]; the app uses
/// `speech_to_text`.
abstract class VoiceTranscriber {
  static VoiceTranscriber Function() create = _SpeechToTextTranscriber.new;

  /// Starts listening and sends incremental transcript updates to [onResult].
  /// Returns false when speech recognition isn't available on this device.
  Future<bool> start(TranscriptCallback onResult);

  Future<void> stop();

  Future<void> cancel();

  Future<void> dispose();
}

class _SpeechToTextTranscriber implements VoiceTranscriber {
  final _speech = SpeechToText();
  bool _ready = false;

  Future<bool> _ensureReady() async {
    if (_ready) return true;
    _ready = await _speech.initialize();
    return _ready;
  }

  @override
  Future<bool> start(TranscriptCallback onResult) async {
    if (!await _ensureReady()) return false;
    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) => onResult(
          result.recognizedWords.trim(),
          isFinal: result.finalResult,
        ),
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
        onDevice: true,
      );
      return true;
    } on Exception {
      return false;
    }
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();

  @override
  Future<void> dispose() => _speech.cancel();
}
