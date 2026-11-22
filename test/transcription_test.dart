import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_note/core/storage/app_database.dart';
import 'package:my_note/core/storage/media_store.dart';
import 'package:my_note/features/backup/data/backup_service.dart';
import 'package:my_note/features/notes/data/notes_repository.dart';
import 'package:my_note/features/notes/domain/note.dart';
import 'package:my_note/features/record/data/transcription_service.dart';
import 'package:my_note/features/record/domain/transcript.dart';
import 'package:my_note/features/search/domain/note_search.dart';

import 'support/fake_transcriber.dart';

Note _voiceNote(String id, String fileName, {String body = ''}) => Note(
  id: id,
  body: body,
  audio: NoteAudio(fileName: fileName, durationMs: 3000),
  createdAt: DateTime(2026, 11, 1),
  updatedAt: DateTime(2026, 11, 1),
);

/// Saves a voice note whose recording file exists.
Note _record(String id, String fileName, {String body = ''}) {
  File(MediaStore.audio.pathOf(fileName)).writeAsStringSync('aac');
  final note = _voiceNote(id, fileName, body: body);
  NotesRepository.instance.save(note);
  return note;
}

void main() {
  group('cleanTranscript', () {
    test('drops sound markers and extra spaces', () {
      expect(
        cleanTranscript(' [BLANK_AUDIO] Buy  milk (coughs) and eggs. *music*'),
        'Buy milk and eggs.',
      );
    });

    test('is empty when nothing was said', () {
      expect(cleanTranscript('[BLANK_AUDIO]\n [ Silence ] '), '');
    });

    test('keeps line breaks between sentences', () {
      expect(cleanTranscript(' First.\n\n Second. '), 'First.\nSecond.');
    });
  });

  group('appendTranscript', () {
    test('fills an empty body', () {
      expect(appendTranscript('  \n', 'Hello there'), 'Hello there');
    });

    test('goes after existing text, never replacing it', () {
      expect(appendTranscript('My notes\n', 'Hello'), 'My notes\n\nHello');
    });

    test('leaves the body alone for an empty transcript', () {
      expect(appendTranscript('My notes', '  '), 'My notes');
    });
  });

  test('a transcribed recording round-trips through JSON', () {
    const audio = NoteAudio(
      fileName: 'voice_1.m4a',
      durationMs: 10,
      transcribed: true,
    );
    final back = NoteAudio.fromJson(audio.toJson());
    expect(back.transcribed, isTrue);
    expect(back.fileName, 'voice_1.m4a');
    // Notes saved before transcription existed read as not transcribed.
    expect(
      NoteAudio.fromJson({'fileName': 'old.m4a', 'durationMs': 1}).transcribed,
      isFalse,
    );
  });

  group('TranscriptionService', () {
    late FakeTranscriber fake;
    late TranscriptionService service;

    setUp(() async {
      AppDatabase.openInMemory();
      MediaStore.audio.directory = Directory.systemTemp.createTempSync('tr_a');
      MediaStore.scans.directory = Directory.systemTemp.createTempSync('tr_s');
      await NotesRepository.init();
      fake = FakeTranscriber(
        words: {
          'voice_1.m4a': ' Pick up the groceries [BLANK_AUDIO] ',
          'voice_2.m4a': 'Call the dentist',
          'silent.m4a': '[BLANK_AUDIO]',
        },
      );
      service = TranscriptionService(transcriber: fake);
    });

    test('saves an editable transcript and keeps the audio', () async {
      _record('n1', 'voice_1.m4a');

      expect(await service.transcribe('n1'), TranscriptOutcome.done);

      final note = NotesRepository.instance.byId('n1')!;
      expect(note.body, 'Pick up the groceries');
      expect(note.audio?.fileName, 'voice_1.m4a');
      expect(note.audio?.transcribed, isTrue);
      expect(File(MediaStore.audio.pathOf('voice_1.m4a')).existsSync(), true);
      expect(note.updatedAt.isAfter(DateTime(2026, 11, 1)), isTrue);

      // Stored, not just in memory: a fresh load still has it.
      await NotesRepository.init();
      expect(NotesRepository.instance.byId('n1')!.body, note.body);
    });

    test('the transcript is searchable', () async {
      _record('n1', 'voice_1.m4a');
      _record('n2', 'voice_2.m4a');
      await service.transcribe('n1');
      await service.transcribe('n2');

      final hits = searchNotes(NotesRepository.instance.notes, 'groceries');
      expect([for (final h in hits) h.note.id], ['n1']);
      expect(hits.single.snippet, contains('groceries'));
      expect(
        [
          for (final h in searchNotes(
            NotesRepository.instance.notes,
            'dentist',
          ))
            h.note.id,
        ],
        ['n2'],
      );
    });

    test('adds to what was already written', () async {
      _record('n1', 'voice_1.m4a', body: 'Saturday');
      await service.transcribe('n1');
      expect(
        NotesRepository.instance.byId('n1')!.body,
        'Saturday\n\nPick up the groceries',
      );
    });

    test('hands the words to an open editor instead of saving', () async {
      _record('n1', 'voice_1.m4a');
      final received = <TranscriptResult>[];
      void onResult(TranscriptResult r) => received.add(r);
      service.attach('n1', onResult);

      await service.transcribe('n1');

      expect(received.single.outcome, TranscriptOutcome.done);
      expect(received.single.text, 'Pick up the groceries');
      expect(NotesRepository.instance.byId('n1')!.body, isEmpty);

      service.detach('n1', onResult);
      _record('n2', 'voice_2.m4a');
      await service.transcribe('n2');
      expect(received, hasLength(1));
    });

    test('a recording with no speech leaves the note as it was', () async {
      _record('n1', 'silent.m4a', body: 'Keep me');
      expect(await service.transcribe('n1'), TranscriptOutcome.noSpeech);
      final note = NotesRepository.instance.byId('n1')!;
      expect(note.body, 'Keep me');
      expect(note.audio?.transcribed, isFalse);
    });

    test('reports a missing recording file or note', () async {
      NotesRepository.instance.save(_voiceNote('n1', 'gone.m4a'));
      expect(await service.transcribe('n1'), TranscriptOutcome.missingAudio);
      expect(await service.transcribe('nope'), TranscriptOutcome.missingAudio);
      expect(fake.started, isEmpty);
    });

    test('a Whisper failure changes nothing and frees the queue', () async {
      _record('n1', 'unknown.m4a');
      _record('n2', 'voice_2.m4a');
      expect(await service.transcribe('n1'), TranscriptOutcome.failed);
      expect(NotesRepository.instance.byId('n1')!.body, isEmpty);
      expect(service.isTranscribing('n1'), isFalse);
      expect(await service.transcribe('n2'), TranscriptOutcome.done);
    });

    test('runs one recording at a time, reporting progress', () async {
      _record('n1', 'voice_1.m4a');
      _record('n2', 'voice_2.m4a');
      fake.gate = Completer();

      final first = service.transcribe('n1');
      final second = service.transcribe('n2');
      await pumpEventQueue();

      expect(fake.started, ['voice_1.m4a']);
      expect(service.progressOf('n1'), 0.5);
      expect(service.isTranscribing('n2'), isTrue);
      expect(service.progressOf('n2'), isNull, reason: 'still waiting');

      // Asking again for a queued note doesn't start a second job.
      final again = service.transcribe('n1');
      fake.gate!.complete();
      expect(await first, TranscriptOutcome.done);
      expect(await second, TranscriptOutcome.done);
      expect(await again, TranscriptOutcome.done);
      expect(fake.started, ['voice_1.m4a', 'voice_2.m4a']);
      expect(service.isTranscribing('n1'), isFalse);
      expect(
        NotesRepository.instance.byId('n1')!.body,
        'Pick up the groceries',
      );
    });

    test('words go only to the recording they came from', () async {
      _record('n1', 'voice_1.m4a');
      fake.gate = Completer();
      final job = service.transcribe('n1');
      await pumpEventQueue();
      // The recording is removed while Whisper works.
      final repo = NotesRepository.instance;
      repo.save(repo.byId('n1')!.copyWith(audio: () => null));
      fake.gate!.complete();

      expect(await job, TranscriptOutcome.missingAudio);
      expect(repo.byId('n1')!.body, isEmpty);
    });

    test('transcripts survive a backup and restore', () async {
      _record('n1', 'voice_1.m4a');
      await service.transcribe('n1');
      final zip = BackupService.export(now: DateTime(2026, 11, 22));

      // A new phone.
      AppDatabase.openInMemory();
      MediaStore.audio.directory = Directory.systemTemp.createTempSync('tr_b');
      BackupService.restore(zip);
      await NotesRepository.init();

      final note = NotesRepository.instance.byId('n1')!;
      expect(note.body, 'Pick up the groceries');
      expect(note.audio?.transcribed, isTrue);
      expect(File(MediaStore.audio.pathOf('voice_1.m4a')).existsSync(), true);
    });
  });
}
