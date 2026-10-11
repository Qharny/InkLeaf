import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/sketch_styles.dart';
import '../../../core/storage/audio_store.dart';
import '../../../core/utils/relative_time.dart';
import '../domain/note.dart';

/// Play/pause, seek bar and times for a note's recording.
///
/// The audio player is only created on first play, so opening a voice note
/// costs nothing until it is listened to.
class VoiceNotePlayer extends StatefulWidget {
  const VoiceNotePlayer({
    super.key,
    required this.audio,
    required this.onRemove,
  });

  final NoteAudio audio;
  final VoidCallback onRemove;

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  AudioPlayer? _player;
  final _subs = <StreamSubscription<void>>[];
  Duration _position = Duration.zero;
  Duration? _loadedDuration;
  bool _playing = false;
  bool _started = false;
  bool _missing = false;

  Duration get _duration {
    final saved = widget.audio.duration;
    return saved > Duration.zero ? saved : _loadedDuration ?? Duration.zero;
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _player?.dispose();
    super.dispose();
  }

  AudioPlayer _createPlayer() {
    final player = AudioPlayer();
    _subs
      ..add(
        player.onPositionChanged.listen((p) => setState(() => _position = p)),
      )
      ..add(
        player.onDurationChanged.listen(
          (d) => setState(() => _loadedDuration = d),
        ),
      )
      ..add(
        player.onPlayerComplete.listen(
          (_) => setState(() {
            _playing = false;
            _started = false;
            _position = Duration.zero;
          }),
        ),
      );
    return player;
  }

  Future<void> _toggle() async {
    final player = _player;
    if (_playing && player != null) {
      await player.pause();
      setState(() => _playing = false);
      return;
    }
    final path = AudioStore.pathOf(widget.audio.fileName);
    if (!File(path).existsSync()) {
      setState(() => _missing = true);
      return;
    }
    final p = _player ??= _createPlayer();
    if (_started) {
      await p.resume();
    } else {
      await p.play(DeviceFileSource(path), position: _position);
      _started = true;
    }
    if (mounted) setState(() => _playing = true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final total = _duration;
    final maxMs = total.inMilliseconds.clamp(1, 1 << 31).toDouble();

    return Material(
      color: scheme.surfaceContainerLowest.withValues(alpha: 0.6),
      shape: SketchBorder(
        side: BorderSide(color: scheme.outline, width: 1.2),
        radius: 28,
        seed: widget.audio.fileName.hashCode,
        passes: 1,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
        child: Row(
          children: [
            IconButton.filledTonal(
              tooltip: _playing ? 'Pause' : 'Play recording',
              icon: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
              onPressed: _missing ? null : _toggle,
            ),
            Expanded(
              child: _missing
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'The recording file is missing.',
                        style: text.bodyMedium?.copyWith(color: scheme.error),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Slider(
                          value: _position.inMilliseconds
                              .clamp(0, maxMs)
                              .toDouble(),
                          max: maxMs,
                          semanticFormatterCallback: (v) =>
                              formatDuration(Duration(milliseconds: v.round())),
                          onChanged: (v) => setState(
                            () => _position = Duration(milliseconds: v.round()),
                          ),
                          onChangeEnd: (v) =>
                              _player?.seek(Duration(milliseconds: v.round())),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              Text(
                                formatDuration(_position),
                                style: text.labelMedium,
                              ),
                              const Spacer(),
                              Text(
                                formatDuration(total),
                                style: text.labelMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            IconButton(
              tooltip: 'Remove recording',
              icon: const Icon(Icons.close_rounded),
              onPressed: widget.onRemove,
            ),
          ],
        ),
      ),
    );
  }
}
