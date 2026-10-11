// Renders README screenshots of the real app, seeded with sample notes.
//
//   flutter test tool/take_screenshots.dart
//
// Writes PNGs to docs/screenshots/ and the delete animation's frames to
// build/screenshots/bin_frames/ (turned into a GIF separately). Not part of
// the test suite: CI only runs test/.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_note/app/app.dart';
import 'package:my_note/core/navigation/pending_note.dart';
import 'package:my_note/core/storage/app_database.dart';
import 'package:my_note/core/storage/app_prefs.dart';
import 'package:my_note/core/storage/media_store.dart';
import 'package:my_note/features/canvas/data/boards_repository.dart';
import 'package:my_note/features/canvas/domain/board.dart';
import 'package:my_note/features/collections/data/collections_repository.dart';
import 'package:my_note/features/collections/domain/collection.dart';
import 'package:my_note/features/notes/data/notes_repository.dart';
import 'package:my_note/features/notes/domain/note.dart';
import 'package:my_note/features/notes/presentation/bin_animation.dart';
import 'package:my_note/features/reminders/data/reminders.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _shot = GlobalKey();
const _out = 'docs/screenshots';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    // Real icons instead of the test font's boxes.
    final icons = File(
      '${_flutterRoot()}/bin/cache/artifacts/material_fonts/'
      'MaterialIcons-Regular.otf',
    ).readAsBytesSync();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.view(icons.buffer)))).load();
    Directory(_out).createSync(recursive: true);
  });

  testWidgets('home', (t) async {
    await _launch(t);
    await _capture(t, 'home');
  });

  testWidgets('home, night theme', (t) async {
    await _launch(t, theme: 'dark');
    await _capture(t, 'home_dark');
  });

  testWidgets('note editor with a checklist', (t) async {
    await _launch(t);
    await t.tap(find.text('Groceries').first);
    await _settle(t);
    await _capture(t, 'editor');
  });

  testWidgets('formatting and links', (t) async {
    await _launch(t);
    await t.tap(find.text('Weekend plan').first);
    await _settle(t);
    // Put the caret in the body so the formatting toolbar shows.
    await t.tap(find.textContaining('Saturday', findRichText: true).first);
    await _settle(t);
    await _capture(t, 'formatting');
  });

  testWidgets('collections drawer', (t) async {
    await _launch(t);
    await t.tap(find.widgetWithText(NavigationDestination, 'Collections'));
    await _settle(t);
    await _capture(t, 'collections');
  });

  testWidgets('canvas', (t) async {
    await _launch(t);
    await t.tap(find.widgetWithText(NavigationDestination, 'Canvas'));
    await _settle(t);
    await t.tap(find.text('Launch plan'));
    await _settle(t);
    await _capture(t, 'canvas');
  });

  testWidgets('search', (t) async {
    await _launch(t);
    await t.tap(find.widgetWithText(NavigationDestination, 'Search'));
    await _settle(t);
    await t.enterText(find.byType(TextField).first, 'book');
    await _settle(t);
    FocusManager.instance.primaryFocus?.unfocus();
    await _settle(t);
    await _capture(t, 'search');
  });

  testWidgets('onboarding', (t) async {
    await _launch(t, onboarded: false);
    await _capture(t, 'onboarding');
  });

  testWidgets('delete animation frames', (t) async {
    await _launch(t);
    final title = find.text('Trip to Accra');
    throwInBin(
      t.element(title),
      from: _cardRect(t, title)!,
      paper: const Color(0xFFD9E6CB),
    );
    // As in the app: the note leaves the desk as the animation starts.
    NotesRepository.instance.moveToTrash('trip');
    final dir = Directory('build/screenshots/bin_frames')
      ..createSync(recursive: true);
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(milliseconds: 55));
      await _capture(
        t,
        'frame_${i.toString().padLeft(2, '0')}',
        dir: dir.path,
        pixelRatio: 1,
      );
    }
    await t.pump(const Duration(seconds: 1));
  });
}

/// The note card around [text]: its nearest card-sized ancestor.
Rect? _cardRect(WidgetTester t, Finder text) {
  Rect? found;
  t.element(text).visitAncestorElements((e) {
    final r = e.renderObject;
    if (r is RenderBox && r.hasSize && r.size.height >= 120) {
      found = r.localToGlobal(Offset.zero) & r.size;
      return false;
    }
    return true;
  });
  return found;
}

String _flutterRoot() {
  final env = Platform.environment['FLUTTER_ROOT'];
  if (env != null) return env;
  final flutter = Process.runSync('which', ['flutter']).stdout.toString();
  return File(File(flutter.trim()).resolveSymbolicLinksSync())
      .parent
      .parent
      .path;
}

Future<void> _launch(
  WidgetTester t, {
  bool onboarded = true,
  String theme = 'light',
}) async {
  // A phone-sized screen: 390 x 844 logical pixels.
  t.view.physicalSize = const Size(1170, 2532);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);

  // A tool run like a test, so the in-memory preferences are fine here.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({
    'onboarding_done': onboarded,
    'theme_mode': theme,
  });
  await AppPrefs.init();
  MediaStore.audio.directory = Directory.systemTemp.createTempSync('shot_a');
  MediaStore.scans.directory = Directory.systemTemp.createTempSync('shot_s');
  AppDatabase.openInMemory();
  await NotesRepository.init();
  await BoardsRepository.init();
  await CollectionsRepository.init();
  _seed();
  pendingNoteToOpen.value = null;
  await Reminders.instance.init(_NoReminders());

  await t.pumpWidget(RepaintBoundary(key: _shot, child: const InkleafApp()));
  // Splash, its hold, then the fade to the next screen.
  await t.pump(const Duration(seconds: 2));
  await t.pump(const Duration(seconds: 1));
  await _settle(t);
}

Future<void> _settle(WidgetTester t) async {
  await t.pumpAndSettle();
  await t.runAsync(GoogleFonts.pendingFonts);
  await t.pumpAndSettle();
}

Future<void> _capture(
  WidgetTester t,
  String name, {
  String dir = _out,
  double pixelRatio = 2,
}) async {
  final boundary =
      _shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await t.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File('$dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
  debugPrint('wrote $dir/$name.png');
}

void _seed() {
  final now = DateTime.now();
  DateTime ago(int minutes) => now.subtract(Duration(minutes: minutes));
  final tomorrow7pm = DateTime(now.year, now.month, now.day + 1, 19);

  Note note(
    String id,
    String title, {
    String body = '',
    int color = 0,
    bool pinned = false,
    List<String> tags = const [],
    List<ChecklistItem> checklist = const [],
    List<BoardStroke> sketch = const [],
    NoteAudio? audio,
    String? scanFile,
    DateTime? remindAt,
    required int minutesAgo,
  }) => Note(
    id: id,
    title: title,
    body: body,
    color: color,
    pinned: pinned,
    tags: tags,
    checklist: checklist,
    sketch: sketch,
    audio: audio,
    scanFile: scanFile,
    remindAt: remindAt,
    createdAt: ago(minutesAgo + 60),
    updatedAt: ago(minutesAgo),
  );

  for (final n in [
    note(
      'groceries',
      'Groceries',
      pinned: true,
      tags: ['home'],
      checklist: const [
        ChecklistItem(id: 'g1', text: 'Oat milk', done: true),
        ChecklistItem(id: 'g2', text: 'Sourdough loaf', done: true),
        ChecklistItem(id: 'g3', text: 'Fresh basil'),
        ChecklistItem(id: 'g4', text: 'Plantains'),
      ],
      minutesAgo: 12,
    ),
    note(
      'ideas',
      'App ideas',
      body:
          'A notebook that feels like paper but searches like a computer. '
          'Cards you can pin to a canvas and connect with arrows.',
      color: 3,
      pinned: true,
      tags: ['ideas'],
      minutesAgo: 95,
    ),
    note(
      'books',
      'Book club picks',
      body:
          'The Overstory by Richard Powers\nPiranesi by Susanna Clarke\n'
          'Things Fall Apart by Chinua Achebe',
      color: 1,
      tags: ['reading'],
      remindAt: tomorrow7pm,
      minutesAgo: 40,
    ),
    note(
      'weekend',
      'Weekend plan',
      body:
          '## Saturday\n'
          '- **Market** early, before the crowds\n'
          '- Call *grandma*\n'
          '- ~~Fix the bike~~ done!\n\n'
          '## Sunday\n'
          '1. Read on the balcony\n'
          '2. Plan the trip: see [[Trip to Accra]]',
      color: 1,
      minutesAgo: 5,
    ),
    note(
      'trip',
      'Trip to Accra',
      body:
          'Land 14:20. Jamestown lighthouse at sunset, then dinner at '
          'Osu. Pack the film camera.',
      color: 2,
      tags: ['travel'],
      minutesAgo: 180,
    ),
    note(
      'standup',
      'Standup thoughts',
      color: 4,
      audio: const NoteAudio(fileName: 'voice_1.m4a', durationMs: 83000),
      minutesAgo: 300,
    ),
    note(
      'receipt',
      'Café receipt',
      body: 'Flat white 2x\nAlmond croissant\nTotal 74.00',
      color: 1,
      scanFile: 'scan_1.jpg',
      minutesAgo: 1500,
    ),
    note(
      'garden',
      'Garden layout',
      color: 2,
      sketch: _gardenSketch(),
      minutesAgo: 2900,
    ),
  ]) {
    NotesRepository.instance.save(n);
  }

  for (final c in [
    Collection(
      id: 'c_work',
      name: 'Work',
      cover: 3,
      noteIds: const ['ideas', 'standup'],
      createdAt: ago(5000),
      updatedAt: ago(5000),
    ),
    Collection(
      id: 'c_reading',
      name: 'Reading',
      cover: 4,
      noteIds: const ['books'],
      createdAt: ago(4000),
      updatedAt: ago(4000),
    ),
    Collection(
      id: 'c_travel',
      name: 'Travel',
      cover: 2,
      noteIds: const ['trip', 'receipt'],
      createdAt: ago(3000),
      updatedAt: ago(3000),
    ),
    Collection(
      id: 'c_home',
      name: 'Home',
      cover: 0,
      noteIds: const ['groceries', 'garden', 'receipt'],
      createdAt: ago(2000),
      updatedAt: ago(2000),
    ),
  ]) {
    CollectionsRepository.instance.save(c);
  }

  const x = boardSize / 2, y = boardSize / 2;
  BoardsRepository.instance.save(
    Board(
      id: 'b_launch',
      title: 'Launch plan',
      createdAt: ago(800),
      updatedAt: ago(30),
      cards: const [
        BoardCard(
          id: 'k1',
          kind: BoardCardKind.sticky,
          text: 'Ship version 1',
          x: x - 170,
          y: y - 240,
        ),
        BoardCard(
          id: 'k2',
          kind: BoardCardKind.note,
          noteId: 'ideas',
          color: 3,
          x: x - 190,
          y: y + 20,
          width: 200,
          height: 150,
        ),
        BoardCard(
          id: 'k3',
          kind: BoardCardKind.sticky,
          text: 'Find 20 beta testers',
          color: 1,
          x: x + 60,
          y: y - 60,
          width: 160,
          height: 120,
        ),
        BoardCard(
          id: 'k4',
          kind: BoardCardKind.sticky,
          text: 'Write the release notes',
          color: 4,
          x: x + 20,
          y: y + 230,
          width: 170,
          height: 120,
        ),
      ],
      links: const [
        BoardLink(id: 'l1', from: 'k1', to: 'k2'),
        BoardLink(id: 'l2', from: 'k1', to: 'k3'),
        BoardLink(id: 'l3', from: 'k3', to: 'k4'),
      ],
      strokes: [_circle(const Offset(x - 70, y - 175), 120, 0xFFC0563B)],
    ),
  );
}

BoardStroke _circle(Offset c, double r, int color) => BoardStroke(
  id: 'circle$color',
  color: color,
  width: 3,
  points: [
    for (var a = 0.0; a <= 6.5; a += 0.15)
      c + Offset.fromDirection(a, r * (1 + 0.04 * (a % 1))),
  ],
);

List<BoardStroke> _gardenSketch() {
  BoardStroke line(String id, List<Offset> points, [int color = 0xFF292B28]) =>
      BoardStroke(id: id, points: points, color: color, width: 3);
  return [
    line('bed1', const [
      Offset(20, 20),
      Offset(160, 20),
      Offset(160, 70),
      Offset(20, 70),
      Offset(20, 20),
    ]),
    line('bed2', const [
      Offset(20, 100),
      Offset(90, 100),
      Offset(90, 170),
      Offset(20, 170),
      Offset(20, 100),
    ]),
    line('path', const [
      Offset(120, 100),
      Offset(135, 130),
      Offset(125, 160),
      Offset(140, 190),
    ], 0xFF4F6A4E),
    _circle(const Offset(200, 140), 22, 0xFF4F6A4E),
  ];
}

/// Reminders are off in screenshots.
class _NoReminders implements ReminderScheduler {
  @override
  Future<void> init({required ValueChanged<String> onOpen}) async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> schedule({
    required String noteId,
    required DateTime at,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> cancel(String noteId) async {}

  @override
  Future<String?> launchNoteId() async => null;
}
