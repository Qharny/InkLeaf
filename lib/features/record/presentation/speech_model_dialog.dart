import 'package:flutter/material.dart';

import '../data/transcriber.dart';
import '../data/transcription_service.dart';

/// Makes sure the speech model is on the phone, asking before the one-time
/// download and showing its progress. True once it's ready.
Future<bool> ensureSpeechModel(BuildContext context) async {
  final transcriber = TranscriptionService.instance.transcriber;
  if (await transcriber.modelReady()) return true;
  if (!context.mounted) return false;

  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Download the speech model?'),
      content: const Text(
        'To turn recordings into text, Inkleaf needs a speech model '
        '(${Transcriber.modelSize}). It is downloaded once from Hugging Face. '
        'After that, transcription runs on your phone and works offline: '
        'your recordings are never uploaded.\n\n'
        'Use Wi-Fi if your mobile data is limited.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Not now'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Download'),
        ),
      ],
    ),
  );
  if (!(ok ?? false) || !context.mounted) return false;

  final done = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DownloadDialog(transcriber: transcriber),
  );
  return done ?? false;
}

class _DownloadDialog extends StatefulWidget {
  const _DownloadDialog({required this.transcriber});

  final Transcriber transcriber;

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  double? _progress;
  bool _cancelled = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    if (_failed) {
      setState(() {
        _failed = false;
        _progress = null;
      });
    }
    try {
      await widget.transcriber.downloadModel(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        cancelled: () => _cancelled,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on DownloadCancelled {
      // Closed by the cancel button already.
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _cancel() {
    _cancelled = true;
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final percent = _progress == null ? null : (_progress! * 100).round();
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(_failed ? "Couldn't download" : 'Downloading'),
        content: _failed
            ? const Text(
                'Check your internet connection and try again. Nothing was '
                'saved, so the download starts over.',
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: _progress),
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      percent == null
                          ? 'Starting…'
                          : '$percent% of ${Transcriber.modelSize}',
                    ),
                  ),
                ],
              ),
        actions: [
          TextButton(onPressed: _cancel, child: const Text('Cancel')),
          if (_failed)
            TextButton(onPressed: _download, child: const Text('Try again')),
        ],
      ),
    );
  }
}
