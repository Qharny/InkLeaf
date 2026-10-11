import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_note/app/app.dart';
import 'package:my_note/core/storage/app_prefs.dart';
import 'package:my_note/core/storage/audio_store.dart';
import 'package:my_note/features/canvas/data/boards_repository.dart';
import 'package:my_note/features/notes/data/notes_repository.dart';
import 'package:my_note/features/canvas/domain/board.dart';
import 'package:my_note/features/collections/data/collections_repository.dart';
import 'package:my_note/features/notes/domain/note.dart';
import 'package:my_note/features/record/data/voice_recorder.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> startApp(
  WidgetTester tester, {
  bool onboardingDone = false,
  List<Note> notes = const [],
}) async {
  SharedPreferences.setMockInitialValues({
    'onboarding_done': onboardingDone,
    'notes': jsonEncode([for (final n in notes) n.toJson()]),
  });
  await AppPrefs.init();
  AudioStore.directory = Directory.systemTemp.createTempSync('inkleaf_audio');
  await NotesRepository.init();
  await BoardsRepository.init();
  await CollectionsRepository.init();
  await tester.pumpWidget(const InkleafApp());
  // Splash animation, its hold, then the fade to the next screen.
  await tester.pump(const Duration(seconds: 2));
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('first run: splash, onboarding pages, then home', (tester) async {
    await startApp(tester);

    expect(find.text('in ink'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    expect(find.text('again'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Inkleaf'), findsOneWidget);
    expect(AppPrefs.instance.onboardingDone, isTrue);
  });

  testWidgets('skip goes straight to home', (tester) async {
    await startApp(tester);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Inkleaf'), findsOneWidget);
    expect(AppPrefs.instance.onboardingDone, isTrue);
  });

  testWidgets('returning user skips onboarding; tabs switch', (tester) async {
    await startApp(tester, onboardingDone: true);

    expect(find.widgetWithText(AppBar, 'Inkleaf'), findsOneWidget);

    await tester.tap(find.text('Collections'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Collections'), findsOneWidget);
  });

  group('home', () {
    final t = DateTime(2026, 1, 1);
    Note note(
      String id,
      String title, {
      bool pinned = false,
      List<String> tags = const [],
    }) => Note(
      id: id,
      title: title,
      body: '$title body',
      pinned: pinned,
      tags: tags,
      createdAt: t,
      updatedAt: t,
    );

    testWidgets('empty desk offers to write a note, which then shows up', (
      tester,
    ) async {
      await startApp(tester, onboardingDone: true);
      expect(find.text('Nothing here yet'), findsOneWidget);

      await tester.tap(find.text('Write your first note'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'Groceries',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Start writing…'),
        'Eggs',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('1 note on your desk'), findsOneWidget);
      expect(NotesRepository.instance.notes.single.body, 'Eggs');
    });

    testWidgets('a new note left empty is discarded', (tester) async {
      await startApp(tester, onboardingDone: true);
      await tester.tap(find.text('Write your first note'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Nothing here yet'), findsOneWidget);
    });

    testWidgets('pinned section, search and tag filter', (tester) async {
      await startApp(
        tester,
        onboardingDone: true,
        notes: [
          note('a', 'Pinned idea', pinned: true),
          note('b', 'Trip plan', tags: ['travel']),
          note('c', 'Book list'),
        ],
      );
      expect(find.text('Pinned'), findsOneWidget);
      expect(find.text('3 notes on your desk'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Search your notes'),
        'trip',
      );
      await tester.pumpAndSettle();
      expect(find.text('Trip plan'), findsOneWidget);
      expect(find.text('Book list'), findsNothing);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.tap(find.text('#travel').first);
      await tester.pumpAndSettle();
      expect(find.text('Trip plan'), findsOneWidget);
      expect(find.text('Pinned idea'), findsNothing);
    });

    testWidgets('long-press: trash with undo, and pin', (tester) async {
      await startApp(
        tester,
        onboardingDone: true,
        notes: [note('a', 'Old draft')],
      );

      await tester.longPress(find.text('Old draft'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move to trash'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(NotesRepository.instance.trashed, hasLength(1));

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Old draft'), findsOneWidget);

      await tester.longPress(find.text('Old draft'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pin to top'));
      await tester.pumpAndSettle();
      expect(find.text('Pinned'), findsOneWidget);
    });

    testWidgets('notes are saved across restarts', (tester) async {
      await startApp(
        tester,
        onboardingDone: true,
        notes: [note('a', 'Keep me')],
      );
      NotesRepository.instance.togglePin('a');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('notes'), contains('"pinned":true'));
    });
  });

  testWidgets('search tab: results, #tag, recent searches', (tester) async {
    final t = DateTime(2026, 1, 1);
    await startApp(
      tester,
      onboardingDone: true,
      notes: [
        Note(
          id: 'a',
          title: 'Trip plan',
          body: 'Pack the camera',
          tags: ['travel'],
          createdAt: t,
          updatedAt: t,
        ),
        Note(id: 'b', title: 'Book list', createdAt: t, updatedAt: t),
      ],
    );
    await tester.tap(find.text('Search').last);
    await tester.pumpAndSettle();
    expect(find.text('Find anything'), findsOneWidget);

    final box = find.widgetWithText(TextField, 'Search titles, text and #tags');
    await tester.enterText(box, 'camera');
    await tester.pumpAndSettle();
    expect(find.text('1 result'), findsOneWidget);

    await tester.enterText(box, 'nope');
    await tester.pumpAndSettle();
    expect(find.text('No results'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, '#travel'));
    await tester.pumpAndSettle();
    expect(find.text('1 result'), findsOneWidget);

    await tester.tap(find.textContaining('Trip plan', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Title'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Recent searches'), findsOneWidget);
    expect(AppPrefs.instance.recentSearches, ['#travel']);
  });

  group('canvas', () {
    Future<void> openCanvasTab(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(NavigationDestination, 'Canvas'));
      await tester.pumpAndSettle();
    }

    testWidgets('build a board: sticky, note card, arrow, undo, drawing', (
      tester,
    ) async {
      final t = DateTime(2026, 1, 1);
      await startApp(
        tester,
        onboardingDone: true,
        notes: [Note(id: 'n', title: 'Trip plan', createdAt: t, updatedAt: t)],
      );
      await openCanvasTab(tester);
      expect(find.text('Think visually'), findsOneWidget);

      await tester.tap(find.text('New canvas'));
      await tester.pumpAndSettle();
      expect(find.text('Untitled canvas'), findsOneWidget);

      await tester.tap(find.byTooltip('Add sticky note'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Big idea');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Big idea'), findsOneWidget);

      await tester.tap(find.byTooltip('Add a note'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trip plan'));
      await tester.pumpAndSettle();
      expect(find.text('Trip plan'), findsOneWidget);

      Board board() => BoardsRepository.instance.boards.single;
      expect(board().cards, hasLength(2));

      await tester.tap(find.byTooltip('Connect cards'));
      await tester.pumpAndSettle();
      // The note card overlaps the sticky's middle; tap its free corner.
      await tester.tapAt(
        tester.getTopLeft(find.text('Big idea')) + const Offset(8, 8),
      );
      await tester.pump();
      expect(find.text('Now tap the card it points to'), findsOneWidget);
      await tester.tap(find.text('Trip plan'));
      await tester.pumpAndSettle();
      expect(board().links, hasLength(1));

      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      expect(board().links, isEmpty);
      await tester.tap(find.byTooltip('Redo'));
      await tester.pumpAndSettle();
      expect(board().links, hasLength(1));

      await tester.tap(find.byTooltip('Pen'));
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(120, 180), const Offset(120, 60));
      await tester.pumpAndSettle();
      expect(board().strokes, hasLength(1));

      await tester.tap(find.byTooltip('Eraser'));
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(150, 140), const Offset(80, 120));
      await tester.pumpAndSettle();
      expect(board().strokes, isEmpty);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.textContaining('2 cards'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('boards'), contains('Big idea'));
    });

    testWidgets('an untouched new canvas is discarded', (tester) async {
      await startApp(tester, onboardingDone: true);
      await openCanvasTab(tester);
      await tester.tap(find.text('New canvas'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(BoardsRepository.instance.boards, isEmpty);
      expect(find.text('Think visually'), findsOneWidget);
    });

    testWidgets('drag moves a card and can be undone', (tester) async {
      await startApp(tester, onboardingDone: true);
      await openCanvasTab(tester);
      await tester.tap(find.text('New canvas'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add sticky note'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      BoardCard card() => BoardsRepository.instance.boards.single.cards.single;
      final start = card().rect.topLeft;
      await tester.drag(find.text('Double-tap to write'), const Offset(60, 40));
      await tester.pumpAndSettle();
      expect(card().rect.topLeft - start, const Offset(60, 40));

      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      expect(card().rect.topLeft, start);
    });
  });

  group('collections', () {
    final t = DateTime(2026, 1, 1);
    final seed = [
      Note(id: 'p', title: 'Pasta', createdAt: t, updatedAt: t),
      Note(id: 'q', title: 'Quiz answers', createdAt: t, updatedAt: t),
    ];

    Future<void> openTab(WidgetTester tester) async {
      await tester.tap(
        find.widgetWithText(NavigationDestination, 'Collections'),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('create, add notes, write into it, remove with undo', (
      tester,
    ) async {
      await startApp(tester, onboardingDone: true, notes: seed);
      await openTab(tester);
      expect(find.text('Your bookshelf'), findsOneWidget);

      await tester.tap(find.text('New collection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create'));
      await tester.pump();
      expect(find.text('Give it a name'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Recipes');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Recipes'), findsOneWidget);
      expect(find.text('This notebook is empty'), findsOneWidget);

      await tester.tap(find.text('Add existing notes'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Pasta'));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Pasta'), findsOneWidget);
      expect(find.text('Quiz answers'), findsNothing);
      expect(find.text('1 note'), findsOneWidget);

      await tester.tap(find.text('New note'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Soup');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Soup'), findsOneWidget);
      expect(find.text('2 notes'), findsOneWidget);

      await tester.longPress(find.text('Pasta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from Recipes'));
      await tester.pumpAndSettle();
      expect(find.text('Pasta'), findsNothing);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Pasta'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Recipes'), findsOneWidget);
      expect(find.text('2 notes'), findsOneWidget);
    });

    testWidgets('note editor files a note into a new collection', (
      tester,
    ) async {
      await startApp(tester, onboardingDone: true, notes: seed);
      await tester.tap(find.text('Pasta'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Collections'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New collection'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Food');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(
        CollectionsRepository.instance.containing('p').map((c) => c.name),
        ['Food'],
      );
    });

    testWidgets('delete a collection from its page, then undo', (tester) async {
      await startApp(tester, onboardingDone: true, notes: seed);
      await openTab(tester);
      await tester.tap(find.text('New collection'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Temp');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete collection'));
      await tester.pumpAndSettle();
      expect(find.text('Your bookshelf'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Temp'), findsOneWidget);
    });
  });

  group('settings', () {
    Future<void> openSettings(WidgetTester tester) async {
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
    }

    testWidgets('switches to the night theme and remembers it', (tester) async {
      await startApp(tester, onboardingDone: true);
      await openSettings(tester);
      await tester.tap(find.text('Night'));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.text('Night'))).brightness,
        Brightness.dark,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'dark');
    });

    testWidgets('replay the intro', (tester) async {
      await startApp(tester, onboardingDone: true);
      await openSettings(tester);
      await tester.tap(find.text('Replay the intro'));
      await tester.pumpAndSettle();
      expect(find.text('in ink'), findsOneWidget);
      expect(AppPrefs.instance.onboardingDone, isFalse);
    });
  });

  group('draw', () {
    Future<void> openDraw(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Create'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Draw'));
      await tester.pumpAndSettle();
    }

    testWidgets('+ Draw makes a sketch note, opened for titling', (
      tester,
    ) async {
      await startApp(tester, onboardingDone: true);
      await openDraw(tester);
      expect(find.widgetWithText(AppBar, 'Sketch'), findsOneWidget);

      await tester.dragFrom(const Offset(200, 200), const Offset(150, 80));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      final note = NotesRepository.instance.notes.single;
      expect(note.sketch, hasLength(1));
      expect(find.widgetWithText(TextField, 'Title'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Sketch'), findsOneWidget);
    });

    testWidgets('leaving an empty sketch pad saves nothing', (tester) async {
      await startApp(tester, onboardingDone: true);
      await openDraw(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(NotesRepository.instance.notes, isEmpty);
      expect(find.text('Nothing here yet'), findsOneWidget);
    });

    testWidgets('add a sketch to an existing note, then erase it', (
      tester,
    ) async {
      final t = DateTime(2026, 1, 1);
      await startApp(
        tester,
        onboardingDone: true,
        notes: [Note(id: 'a', title: 'Plan', createdAt: t, updatedAt: t)],
      );
      await tester.tap(find.text('Plan'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Sketch'));
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(100, 200), const Offset(200, 0));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(NotesRepository.instance.byId('a')!.sketch, hasLength(1));

      await tester.tap(find.bySemanticsLabel('Sketch. Tap to edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Eraser'));
      await tester.dragFrom(const Offset(200, 150), const Offset(0, 100));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(NotesRepository.instance.byId('a')!.sketch, isEmpty);
    });
  });

  group('record', () {
    tearDown(() => VoiceRecorder.create = _FakeRecorder.new);
    setUp(() => VoiceRecorder.create = _FakeRecorder.new);

    Future<void> openRecorder(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Create'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record'));
      await tester.pumpAndSettle();
    }

    Future<void> startRecording(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Start recording'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('record, stop and save makes a voice note', (tester) async {
      await startApp(tester, onboardingDone: true);
      await openRecorder(tester);
      expect(find.text('Tap to start recording'), findsOneWidget);

      await startRecording(tester);
      expect(find.text('Recording…'), findsOneWidget);
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      expect(find.text('Paused'), findsOneWidget);
      await tester.tap(find.byTooltip('Resume'));
      await tester.pump();

      await tester.tap(find.byTooltip('Stop and save'));
      await tester.pumpAndSettle();
      final note = NotesRepository.instance.notes.single;
      expect(note.audio, isNotNull);
      expect(
        File(AudioStore.pathOf(note.audio!.fileName)).existsSync(),
        isTrue,
      );
      expect(find.byTooltip('Play recording'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Voice note'), findsOneWidget);
    });

    testWidgets('a refused microphone explains and offers to retry', (
      tester,
    ) async {
      VoiceRecorder.create = () => _FakeRecorder(allowed: false);
      await startApp(tester, onboardingDone: true);
      await openRecorder(tester);
      await tester.tap(find.byTooltip('Start recording'));
      await tester.pumpAndSettle();
      expect(find.textContaining('needs microphone access'), findsOneWidget);
      expect(find.byTooltip('Try again'), findsOneWidget);
    });

    testWidgets('discard drops the recording', (tester) async {
      await startApp(tester, onboardingDone: true);
      await openRecorder(tester);
      await startRecording(tester);
      await tester.tap(find.byTooltip('Discard'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(NotesRepository.instance.notes, isEmpty);
      expect(AudioStore.directory.listSync(), isEmpty);
    });

    testWidgets('removing the only recording empties and discards the note', (
      tester,
    ) async {
      await startApp(tester, onboardingDone: true);
      await openRecorder(tester);
      await startRecording(tester);
      await tester.tap(find.byTooltip('Stop and save'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Remove recording'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Play recording'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(NotesRepository.instance.notes, isEmpty);
    });
  });
}

/// Writes a placeholder file instead of using the microphone.
class _FakeRecorder implements VoiceRecorder {
  _FakeRecorder({this.allowed = true});

  final bool allowed;
  String? _path;

  @override
  Future<bool> hasPermission() async => allowed;

  @override
  Future<void> start(String path) async {
    File(path).writeAsStringSync('audio');
    _path = path;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<String?> stop() async => _path;

  @override
  Future<void> cancel() async {
    final path = _path;
    if (path != null) File(path).deleteSync();
    _path = null;
  }

  @override
  Stream<double> levels() => Stream.fromIterable(const [0.2, 0.7, 0.4]);

  @override
  Future<void> dispose() async {}
}
