import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_note/app/app.dart';
import 'package:my_note/core/storage/app_prefs.dart';
import 'package:my_note/features/notes/data/notes_repository.dart';
import 'package:my_note/features/notes/domain/note.dart';
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
  await NotesRepository.init();
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
}
