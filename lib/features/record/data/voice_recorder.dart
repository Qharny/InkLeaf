import 'package:record/record.dart';

/// Records the microphone to a file. An interface so tests can swap in a
/// fake through [create]; the app uses the `record` package.
abstract class VoiceRecorder {
  static VoiceRecorder Function() create = _PackageRecorder.new;

  /// Asks for microphone access if needed; false when refused.
  Future<bool> hasPermission();

  /// Starts recording AAC audio to [path].
  Future<void> start(String path);

  Future<void> pause();

  Future<void> resume();

  /// Stops and returns the file path, or null if nothing was recorded.
  Future<String?> stop();

  /// Stops and deletes the recording.
  Future<void> cancel();

  /// Input loudness from 0 (silence) to 1, a few times a second.
  Stream<double> levels();

  Future<void> dispose();
}

class _PackageRecorder implements VoiceRecorder {
  final _recorder = AudioRecorder();

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start(String path) => _recorder.start(
    const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1),
    path: path,
  );

  @override
  Future<void> pause() => _recorder.pause();

  @override
  Future<void> resume() => _recorder.resume();

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();

  // Amplitude is in dBFS (0 is loudest); treat -50 dB and below as silence.
  @override
  Stream<double> levels() => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 100))
      .map((a) => ((a.current + 50) / 50).clamp(0.0, 1.0));

  @override
  Future<void> dispose() => _recorder.dispose();
}
