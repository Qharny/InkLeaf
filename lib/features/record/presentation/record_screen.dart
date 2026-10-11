import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/sketch_styles.dart';
import '../../../core/storage/audio_store.dart';
import '../../../core/utils/relative_time.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/domain/note.dart';
import '../data/voice_recorder.dart';

enum _Phase { idle, recording, paused, denied }

/// Records a voice note: start, pause and resume, then stop to save it as a
/// new note (opened next so it can be titled), or discard it. Leaving while
/// recording saves, like everything else in Inkleaf.
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final _recorder = VoiceRecorder.create();
  final _clock = Stopwatch();
  final _levels = <double>[];
  _Phase _phase = _Phase.idle;
  String? _fileName;
  Timer? _ticker;
  StreamSubscription<double>? _levelSub;
  bool _closing = false;

  bool get _active => _phase == _Phase.recording || _phase == _Phase.paused;

  @override
  void dispose() {
    _stopTicking();
    // Leaving through a path that didn't save (e.g. the app closing) drops
    // the half-made file rather than orphaning it.
    if (_active && !_closing) _recorder.cancel();
    _recorder.dispose();
    super.dispose();
  }

  void _stopTicking() {
    _ticker?.cancel();
    _ticker = null;
    _levelSub?.cancel();
    _levelSub = null;
    _clock.stop();
  }

  Future<void> _start() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) setState(() => _phase = _Phase.denied);
      return;
    }
    final name = AudioStore.newFileName();
    await _recorder.start(AudioStore.pathOf(name));
    if (!mounted) return;
    _fileName = name;
    _clock
      ..reset()
      ..start();
    _ticker = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => setState(() {}),
    );
    _levelSub = _recorder.levels().listen((level) {
      setState(() {
        _levels.add(level);
        if (_levels.length > 48) _levels.removeAt(0);
      });
    });
    setState(() => _phase = _Phase.recording);
  }

  Future<void> _togglePause() async {
    if (_phase == _Phase.recording) {
      await _recorder.pause();
      _clock.stop();
      setState(() => _phase = _Phase.paused);
    } else {
      await _recorder.resume();
      _clock.start();
      setState(() => _phase = _Phase.recording);
    }
  }

  Future<void> _discard() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard this recording?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep recording'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (!(ok ?? false) || !mounted) return;
    _closing = true;
    _stopTicking();
    await _recorder.cancel();
    if (mounted) context.pop();
  }

  Future<void> _save() async {
    if (_closing) return;
    _closing = true;
    _stopTicking();
    final path = await _recorder.stop();
    final name = _fileName;
    if (!mounted) return;
    if (path == null || name == null) {
      context.pop();
      return;
    }
    final repo = NotesRepository.instance;
    final note = Note.create(color: repo.notes.length % AppColors.notes.length)
        .copyWith(
          audio: () =>
              NoteAudio(fileName: name, durationMs: _clock.elapsedMilliseconds),
        );
    repo.save(note);
    context.pushReplacement(AppRoutes.noteById(note.id));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final status = switch (_phase) {
      _Phase.idle => 'Tap to start recording',
      _Phase.recording => 'Recording…',
      _Phase.paused => 'Paused',
      _Phase.denied =>
        'Inkleaf needs microphone access to record. Allow it in your '
            "phone's settings, then try again.",
    };

    return PopScope(
      canPop: !_active,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _save();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Record')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(),
                Text(
                  formatDuration(_clock.elapsed),
                  style: text.displayLarge?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    status,
                    style: text.bodyLarge?.copyWith(
                      color: _phase == _Phase.denied
                          ? scheme.error
                          : scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 80,
                  width: double.infinity,
                  child: ExcludeSemantics(
                    child: CustomPaint(
                      painter: _LevelMeterPainter(
                        levels: List.of(_levels),
                        color: _phase == _Phase.recording
                            ? scheme.primary
                            : scheme.outlineVariant,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                _buildControls(context),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    if (!_active) {
      return _BigButton(
        tooltip: _phase == _Phase.denied ? 'Try again' : 'Start recording',
        icon: Icons.mic_rounded,
        onPressed: _start,
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton.outlined(
          tooltip: 'Discard',
          iconSize: 28,
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: _discard,
        ),
        _BigButton(
          tooltip: 'Stop and save',
          icon: Icons.stop_rounded,
          recording: true,
          onPressed: _save,
        ),
        IconButton.outlined(
          tooltip: _phase == _Phase.recording ? 'Pause' : 'Resume',
          iconSize: 28,
          icon: Icon(
            _phase == _Phase.recording
                ? Icons.pause_rounded
                : Icons.fiber_manual_record_rounded,
          ),
          onPressed: _togglePause,
        ),
      ],
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.recording = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool recording;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = recording ? scheme.error : scheme.inverseSurface;
    return Tooltip(
      message: tooltip,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: fill,
          foregroundColor: recording ? scheme.onError : scheme.onInverseSurface,
          minimumSize: const Size.square(88),
          padding: EdgeInsets.zero,
          shape: SketchBorder(
            side: BorderSide(color: fill, width: 2),
            radius: 44,
            seed: 9,
          ),
        ),
        child: Icon(icon, size: 40),
      ),
    );
  }
}

/// Recent input levels as a row of rounded bars, newest on the right.
class _LevelMeterPainter extends CustomPainter {
  const _LevelMeterPainter({required this.levels, required this.color});

  static const _slots = 48;

  final List<double> levels;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final step = size.width / _slots;
    final paint = Paint()
      ..color = color
      ..strokeWidth = step * 0.55
      ..strokeCap = StrokeCap.round;
    final mid = size.height / 2;
    for (var i = 0; i < _slots; i++) {
      final index = levels.length - _slots + i;
      final level = index >= 0 ? levels[index] : 0.0;
      final half = (level * size.height / 2).clamp(2.0, size.height / 2);
      final x = step * (i + 0.5);
      canvas.drawLine(Offset(x, mid - half), Offset(x, mid + half), paint);
    }
  }

  @override
  bool shouldRepaint(_LevelMeterPainter old) => true;
}
