import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:my_note/features/record/data/transcriber.dart';

/// Answers with canned words instead of running Whisper.
class FakeTranscriber implements Transcriber {
  FakeTranscriber({this.words = const {}, this.fallback, this.ready = true});

  /// Words for each recording, by file name.
  final Map<String, String> words;

  /// Words for any other recording; without it, those fail.
  final String? fallback;

  /// Whether the speech model counts as downloaded.
  bool ready;

  /// When set, transcriptions wait for it, to test the queue.
  Completer<void>? gate;
  final started = <String>[];
  var downloads = 0;

  @override
  Future<String> transcribe(
    String audioPath, {
    required ValueChanged<double> onProgress,
  }) async {
    final name = audioPath.split(Platform.pathSeparator).last;
    started.add(name);
    onProgress(0.5);
    await gate?.future;
    final text = words[name] ?? fallback;
    if (text == null) throw Exception('Whisper failed');
    return text;
  }

  @override
  Future<bool> modelReady() async => ready;

  @override
  Future<void> downloadModel({
    required ValueChanged<double?> onProgress,
    required bool Function() cancelled,
  }) async {
    downloads++;
    onProgress(1);
    ready = true;
  }

  @override
  Future<void> deleteModel() async => ready = false;
}
