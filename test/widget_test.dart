import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_note/app/app.dart';
import 'package:my_note/core/navigation/pending_note.dart';
import 'package:my_note/core/storage/app_database.dart';
import 'package:my_note/core/storage/app_prefs.dart';
import 'package:my_note/core/storage/media_store.dart';
import 'package:my_note/features/backup/data/backup_io.dart';
import 'package:my_note/features/backup/data/backup_service.dart';
import 'package:my_note/features/canvas/data/boards_repository.dart';
import 'package:my_note/features/notes/data/notes_repository.dart';
import 'package:my_note/features/canvas/domain/board.dart';
import 'package:my_note/features/collections/data/collections_repository.dart';
import 'package:my_note/features/notes/domain/note.dart';
import 'package:my_note/features/record/data/voice_recorder.dart';
import 'package:my_note/features/reminders/data/reminders.dart';
import 'package:my_note/features/scan/data/page_scanner.dart';
import 'package:my_note/features/share/data/share_inbox.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_reminder_scheduler.dart';

Future<void> startApp(
  WidgetTester tester, {
  bool onboardingDone = false,
  List<Note> notes = const [],
  Future<void> Function()? beforeLaunch,
  FakeReminderScheduler? reminders,
}) async {
  SharedPreferences.setMockInitialValues({
    'onboarding_done': onboardingDone,
    'notes': jsonEncode([for (final n in notes) n.toJson()]),
  });
  await AppPrefs.init();
  MediaStore.audio.directory = Directory.systemTemp.createTempSync(
    'inkleaf_audio',
  );
  MediaStore.scans.directory = Directory.systemTemp.createTempSync(
    'inkleaf_scans',
  );
  // Seeded notes arrive through the old SharedPreferences key, so every test
  // also runs the one-time import into the database.
  AppDatabase.openInMemory();
  await AppDatabase.instance.importLegacy(
    await SharedPreferences.getInstance(),
  );
  await NotesRepository.init();
  await BoardsRepository.init();
  await CollectionsRepository.init();
  pendingNoteToOpen.value = null;
  await Reminders.instance.init(reminders ?? FakeReminderScheduler());
  await beforeLaunch?.call();
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
      final saved = AppDatabase.instance.readAll(AppDatabase.notes).single;
      expect(saved['pinned'], isTrue);
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
      final saved = AppDatabase.instance.readAll(AppDatabase.boards).single;
      expect(jsonEncode(saved), contains('Big idea'));
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
      expect(find.text('An empty drawer'), findsOneWidget);

      await tester.tap(find.text('New collection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create'));
      await tester.pump();
      expect(find.text('Give it a name'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Recipes');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      // The new folder drops into the drawer; open it.
      await tester.tap(find.text('Recipes'));
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
      // Collections lives in the editor's "More" menu.
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Collections'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New collection'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Food');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
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
      await tester.tap(find.text('Temp'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete collection'));
      await tester.pumpAndSettle();
      expect(find.text('An empty drawer'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Temp'), findsOneWidget);
    });

    Future<void> createCollection(WidgetTester tester, String name) async {
      await tester.tap(find.byTooltip('New collection'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name'), name);
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
    }

    testWidgets('long-press and drag a folder to reorder the drawer', (
      tester,
    ) async {
      await startApp(tester, onboardingDone: true);
      await openTab(tester);
      await createCollection(tester, 'Older');
      await createCollection(tester, 'Newer');
      List<String> names() => [
        for (final c in CollectionsRepository.instance.collections) c.name,
      ];
      expect(names(), ['Newer', 'Older'], reason: 'new folders go in front');

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Newer')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, 25));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(names(), ['Older', 'Newer']);
    });

    testWidgets('remove from the folder menu slides it out; undo returns', (
      tester,
    ) async {
      await startApp(tester, onboardingDone: true);
      await openTab(tester);
      await createCollection(tester, 'Old trips');

      await tester.tap(find.byTooltip('Folder options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete collection'));
      await tester.pumpAndSettle();
      expect(CollectionsRepository.instance.collections, isEmpty);
      expect(find.text('An empty drawer'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Old trips'), findsOneWidget);
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

    testWidgets('export hands a backup zip to the share sheet', (tester) async {
      final io = _FakeBackupIo();
      BackupIo.create = () => io;
      final t = DateTime(2026, 1, 1);
      await startApp(
        tester,
        onboardingDone: true,
        notes: [Note(id: 'a', title: 'Saved', createdAt: t, updatedAt: t)],
      );
      await openSettings(tester);
      await tester.scrollUntilVisible(find.text('Export a backup'), 200);
      await tester.tap(find.text('Export a backup'));
      await tester.pumpAndSettle();
      expect(io.sharedName, startsWith('inkleaf-backup-'));

      // The shared zip restores the note on a fresh device.
      AppDatabase.openInMemory();
      expect(BackupService.restore(io.shared!).notes, 1);
    });

    testWidgets('restore merges a backup and shows what came back', (
      tester,
    ) async {
      final t = DateTime(2026, 1, 1);
      await startApp(
        tester,
        onboardingDone: true,
        notes: [Note(id: 'a', title: 'Backed up', createdAt: t, updatedAt: t)],
      );
      final zip = BackupService.export();
      final io = _FakeBackupIo()..toPick = zip;
      BackupIo.create = () => io;
      NotesRepository.instance.delete('a');
      await tester.pumpAndSettle();
      expect(find.text('Nothing here yet'), findsOneWidget);

      await openSettings(tester);
      await tester.scrollUntilVisible(find.text('Restore from a backup'), 200);
      await tester.tap(find.text('Restore from a backup'));
      await tester.pumpAndSettle();
      expect(
        find.text('Restored 1 note, 0 canvases, 0 collections'),
        findsOneWidget,
      );
      expect(NotesRepository.instance.byId('a')?.title, 'Backed up');
    });

    testWidgets('replay the intro', (tester) async {
      await startApp(tester, onboardingDone: true);
      await openSettings(tester);
      await tester.scrollUntilVisible(find.text('Replay the intro'), 200);
      await tester.ensureVisible(find.text('Replay the intro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replay the intro'));
      await tester.pumpAndSettle();
      expect(find.text('in ink'), findsOneWidget);
      expect(AppPrefs.instance.onboardingDone, isFalse);
    });
  });

  group('checklists', () {
    testWidgets('build a checklist, tick it off, find it, trim it', (
      tester,
    ) async {
      await startApp(tester, onboardingDone: true);
      await tester.tap(find.text('Write your first note'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Shop');

      await tester.tap(find.text('Checklist'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'List item'),
        'Milk',
      );
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      // The new, empty item is the last one.
      await tester.enterText(
        find.widgetWithText(TextField, 'List item').last,
        'Eggs',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(find.text('1/2 done'), findsOneWidget);
      expect(find.text('Checklist'), findsOneWidget, reason: 'chip is gone');

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('1/2 done'), findsOneWidget);
      final note = NotesRepository.instance.notes.single;
      expect(
        [for (final i in note.checklist) (i.text, i.done)],
        [('Milk', true), ('Eggs', false)],
      );

      await tester.tap(find.text('Search').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search titles, text and #tags'),
        'eggs',
      );
      await tester.pumpAndSettle();
      expect(find.text('1 result'), findsOneWidget);

      await tester.tap(find.textContaining('Shop', findRichText: true).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove item').last);
      await tester.pumpAndSettle();
      expect(find.text('1/1 done'), findsOneWidget);
    });
  });

  group('share into Inkleaf', () {
    testWidgets('shared text and a link become a note that opens', (
      tester,
    ) async {
      await startApp(tester, onboardingDone: true);
      ShareInbox.instance.receive([
        (kind: SharedKind.text, value: 'https://example.com/article'),
        (kind: SharedKind.text, value: 'Read this later'),
      ]);
      await tester.pumpAndSettle();

      final note = NotesRepository.instance.notes.single;
      expect(note.body, 'https://example.com/article\n\nRead this later');
      expect(find.widgetWithText(TextField, 'Title'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('https://example.com/article'), findsOneWidget);
    });

    testWidgets('a shared photo is kept with the note', (tester) async {
      await startApp(tester, onboardingDone: true);
      final photo = File(
        '${Directory.systemTemp.createTempSync('inkleaf_share').path}/p.jpg',
      )..writeAsStringSync('jpg');
      ShareInbox.instance.receive([
        (kind: SharedKind.image, value: photo.path),
      ]);
      await tester.pumpAndSettle();
      final note = NotesRepository.instance.notes.single;
      expect(
        File(MediaStore.scans.pathOf(note.scanFile!)).existsSync(),
        isTrue,
      );
      expect(find.byTooltip('Remove photo'), findsOneWidget);
    });

    testWidgets('nothing usable makes no note', (tester) async {
      await startApp(tester, onboardingDone: true);
      expect(
        ShareInbox.instance.receive([(kind: SharedKind.other, value: 'x')]),
        isNull,
      );
      await tester.pumpAndSettle();
      expect(NotesRepository.instance.notes, isEmpty);
    });

    testWidgets('a share that launched the app opens after the splash', (
      tester,
    ) async {
      ShareReceiver.create = () => _FakeShareReceiver([
        (kind: SharedKind.text, value: 'From another app'),
      ]);
      await startApp(
        tester,
        onboardingDone: true,
        beforeLaunch: ShareInbox.instance.start,
      );
      expect(find.widgetWithText(TextField, 'Title'), findsOneWidget);
      expect(NotesRepository.instance.notes.single.body, 'From another app');
    });
  });

  group('reminders', () {
    final t = DateTime(2026, 1, 1);
    Note plan() => Note(id: 'p', title: 'Dentist', createdAt: t, updatedAt: t);

    testWidgets('set a reminder from the editor; the card shows it', (
      tester,
    ) async {
      final reminders = FakeReminderScheduler();
      await startApp(
        tester,
        onboardingDone: true,
        notes: [plan()],
        reminders: reminders,
      );
      await tester.tap(find.text('Dentist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remind me'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tomorrow morning'));
      await tester.pumpAndSettle();

      final at = NotesRepository.instance.byId('p')!.remindAt!;
      expect((at.hour, at.minute), (9, 0));
      expect(reminders.scheduled['p'], (at, 'Dentist'));
      expect(find.textContaining('Tomorrow, 9:00'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.textContaining('Tomorrow, 9:00'), findsOneWidget);

      // Clearing it from the editor cancels the notification.
      await tester.tap(find.text('Dentist'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove reminder'));
      await tester.pumpAndSettle();
      expect(reminders.scheduled, isEmpty);
      expect(find.text('Remind me'), findsOneWidget);
    });

    testWidgets('says so when notifications are turned off', (tester) async {
      await startApp(
        tester,
        onboardingDone: true,
        notes: [plan()],
        reminders: FakeReminderScheduler(allowed: false),
      );
      await tester.tap(find.text('Dentist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remind me'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next week'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Notifications are off'), findsOneWidget);
      expect(NotesRepository.instance.byId('p')!.remindAt, isNotNull);
    });

    testWidgets('tapping a reminder opens its note', (tester) async {
      final reminders = FakeReminderScheduler();
      await startApp(
        tester,
        onboardingDone: true,
        notes: [plan()],
        reminders: reminders,
      );
      reminders.tap('p');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Dentist'), findsOneWidget);
    });

    testWidgets('a reminder that launched the app opens after the splash', (
      tester,
    ) async {
      await startApp(
        tester,
        onboardingDone: true,
        notes: [plan()],
        reminders: FakeReminderScheduler(launchedBy: 'p'),
      );
      expect(find.widgetWithText(TextField, 'Dentist'), findsOneWidget);
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
        File(MediaStore.audio.pathOf(note.audio!.fileName)).existsSync(),
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
      expect(MediaStore.audio.directory.listSync(), isEmpty);
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

  group('scan', () {
    setUp(() => PageScanner.create = _FakeScanner.new);

    Future<void> openScan(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Create'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan document'));
      await tester.pumpAndSettle();
    }

    testWidgets('photo to text to note, keeping the photo', (tester) async {
      await startApp(tester, onboardingDone: true);
      await openScan(tester);
      expect(find.text('Capture anything'), findsOneWidget);

      await tester.tap(find.text('Take a photo'));
      await tester.pumpAndSettle();
      expect(find.text('Text found'), findsOneWidget);
      final field = find.widgetWithText(TextField, 'Milk\nEggs');
      expect(field, findsOneWidget);
      await tester.enterText(field, 'Milk\nEggs\nBread');

      await tester.tap(find.text('Save as note'));
      await tester.pumpAndSettle();
      final note = NotesRepository.instance.notes.single;
      expect(note.body, 'Milk\nEggs\nBread');
      expect(
        File(MediaStore.scans.pathOf(note.scanFile!)).existsSync(),
        isTrue,
      );
      expect(find.byTooltip('Remove photo'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('Scanned page'), findsOneWidget);
    });

    testWidgets('backing out of the picker changes nothing', (tester) async {
      PageScanner.create = () => _FakeScanner(picks: false);
      await startApp(tester, onboardingDone: true);
      await openScan(tester);
      await tester.tap(find.text('Choose from gallery'));
      await tester.pumpAndSettle();
      expect(find.text('Capture anything'), findsOneWidget);
    });

    testWidgets('leaving without saving deletes the copied photo', (
      tester,
    ) async {
      await startApp(tester, onboardingDone: true);
      await openScan(tester);
      await tester.tap(find.text('Take a photo'));
      await tester.pumpAndSettle();
      expect(MediaStore.scans.directory.listSync(), hasLength(1));

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 20; i++) {
        if (MediaStore.scans.directory.listSync().isEmpty) break;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      expect(MediaStore.scans.directory.listSync(), isEmpty);
      expect(NotesRepository.instance.notes, isEmpty);
    });
  });
}

/// Hands back a placeholder photo and canned text.
class _FakeScanner implements PageScanner {
  _FakeScanner({this.picks = true});

  final bool picks;

  @override
  Future<String?> pickImage({required bool camera}) async {
    if (!picks) return null;
    final dir = Directory.systemTemp.createTempSync('inkleaf_pick');
    return (File('${dir.path}/page.jpg')..writeAsStringSync('jpg')).path;
  }

  @override
  Future<String> recognize(String path) async => 'Milk\nEggs';

  @override
  Future<void> dispose() async {}
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

/// Records what would be shared and returns a canned backup when picking.
class _FakeBackupIo implements BackupIo {
  Uint8List? shared;
  String? sharedName;
  Uint8List? toPick;

  @override
  Future<void> share(Uint8List bytes, String fileName) async {
    shared = bytes;
    sharedName = fileName;
  }

  @override
  Future<Uint8List?> pick() async => toPick;
}

/// Delivers a canned share at launch and nothing afterwards.
class _FakeShareReceiver implements ShareReceiver {
  _FakeShareReceiver(this.atLaunch);

  final List<SharedItem> atLaunch;

  @override
  Future<List<SharedItem>> initial() async => atLaunch;

  @override
  Stream<List<SharedItem>> stream() => const Stream.empty();

  @override
  Future<void> reset() async {}
}
