import 'dart:async';
import 'dart:io';

import 'package:home_widget/home_widget.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../core/navigation/pending_note.dart';
import '../notes/data/notes_repository.dart';
import '../notes/domain/note.dart';

/// The Android home-screen widget: quick-capture buttons and up to three
/// pinned notes.
///
/// Keeps the widget's pinned notes in step with the app, and turns taps on
/// the widget (links like `inkleaf://new?mode=record`) into the right
/// screen, opened once the home screen is showing.
class HomeScreenWidget {
  HomeScreenWidget._();

  static final instance = HomeScreenWidget._();

  /// The Kotlin class that draws the widget.
  static const _provider = 'InkleafWidgetProvider';
  static const _maxPinned = 3;

  /// What the widget currently shows, to skip needless updates.
  String? _shown;

  Future<void> start() async {
    if (!Platform.isAndroid) return;
    try {
      NotesRepository.instance.addListener(_sync);
      await _sync();
      _open(await HomeWidget.initiallyLaunchedFromHomeWidget());
      HomeWidget.widgetClicked.listen(_open);
    } on Exception {
      // No launcher widgets here; the app works the same without them.
    }
  }

  Future<void> _sync() async {
    final notes = NotesRepository.instance.notes;
    final pinned = notes.where((n) => n.pinned).take(_maxPinned).toList();
    final shown = [
      notes.length,
      for (final n in pinned) '${n.id}:${n.displayTitle}',
    ].join('|');
    if (shown == _shown) return;
    _shown = shown;

    await HomeWidget.saveWidgetData<int>('note_count', notes.length);
    await HomeWidget.saveWidgetData<int>('pinned_count', pinned.length);
    for (var i = 0; i < _maxPinned; i++) {
      final note = i < pinned.length ? pinned[i] : null;
      await HomeWidget.saveWidgetData<String>('pinned_id_$i', note?.id);
      await HomeWidget.saveWidgetData<String>(
        'pinned_title_$i',
        note?.displayTitle,
      );
    }
    await HomeWidget.updateWidget(androidName: _provider);
  }

  /// Handles a tap on the widget.
  void _open(Uri? uri) {
    if (uri == null || uri.scheme != 'inkleaf') return;
    switch ((uri.host, uri.queryParameters['mode'])) {
      case ('note', _):
        final id = uri.queryParameters['id'];
        if (id != null) pendingNoteToOpen.value = id;
      case ('new', 'checklist'):
        // A fresh to-do list, ready to type into.
        final repo = NotesRepository.instance;
        final note = Note.create(
          color: repo.notes.length % AppColors.notes.length,
        ).copyWith(title: 'To-do', checklist: [ChecklistItem.create()]);
        repo.save(note);
        pendingNoteToOpen.value = note.id;
      case ('new', 'record'):
        pendingLocationToOpen.value = AppRoutes.newNoteWith(NoteMode.record);
      case ('new', 'scan'):
        pendingLocationToOpen.value = AppRoutes.scan;
      case ('new', _):
        pendingLocationToOpen.value = AppRoutes.newNote;
      case _:
        break; // inkleaf://home: just open the app.
    }
  }
}
