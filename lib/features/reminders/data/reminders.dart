import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/navigation/pending_note.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/domain/note.dart';

/// Shows reminder notifications at set times. An interface so tests can
/// swap in a fake; the app uses `flutter_local_notifications`.
abstract class ReminderScheduler {
  /// Sets up notifications. [onOpen] gets the note id of a tapped reminder
  /// while the app is running.
  Future<void> init({required ValueChanged<String> onOpen});

  /// Asks to show notifications, where the platform needs that. True if
  /// they're allowed.
  Future<bool> requestPermission();

  Future<void> schedule({
    required String noteId,
    required DateTime at,
    required String title,
    required String body,
  });

  Future<void> cancel(String noteId);

  /// The note whose reminder launched the app, if one did.
  Future<String?> launchNoteId();
}

/// A stable notification id for [noteId] (FNV-1a, 31 bits), so the same
/// note always replaces its own reminder.
int reminderIdFor(String noteId) {
  var hash = 0x811c9dc5;
  for (final unit in noteId.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

class PluginReminderScheduler implements ReminderScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Reminders',
      channelDescription: 'Reminders you set on notes',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notification',
    ),
    iOS: DarwinNotificationDetails(),
  );

  @override
  Future<void> init({required ValueChanged<String> onOpen}) async {
    tz_data.initializeTimeZones();
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } on Object {
      // Unknown zone: times are still scheduled, interpreted as UTC.
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        // Permission is asked for when the first reminder is set instead.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final id = response.payload;
        if (id != null) onOpen(id);
      },
    );
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> requestPermission() async {
    final android = _android;
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        true;
  }

  @override
  Future<void> schedule({
    required String noteId,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    // On the minute when the phone allows exact alarms; otherwise Android
    // may deliver a little late to save battery.
    final exact = await _android?.canScheduleExactNotifications() ?? true;
    await _plugin.zonedSchedule(
      id: reminderIdFor(noteId),
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: _details,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      payload: noteId,
    );
  }

  @override
  Future<void> cancel(String noteId) =>
      _plugin.cancel(id: reminderIdFor(noteId));

  @override
  Future<String?> launchNoteId() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (!(details?.didNotificationLaunchApp ?? false)) return null;
    return details?.notificationResponse?.payload;
  }
}

/// Keeps the phone's scheduled notifications in step with notes' reminders.
///
/// It watches [NotesRepository]: setting, moving or clearing a reminder,
/// trashing or restoring a note, and restoring a backup all schedule or
/// cancel the right notification. Every future reminder is scheduled again
/// at launch, which also covers reinstalls and restored backups.
class Reminders {
  Reminders._();

  static final instance = Reminders._();

  ReminderScheduler? _scheduler;
  NotesRepository? _repo;

  /// Reminders currently scheduled, by note id.
  final _scheduled = <String, DateTime>{};

  Future<void> init(ReminderScheduler scheduler) async {
    _repo?.removeListener(_sync);
    _scheduler = scheduler;
    _scheduled.clear();
    try {
      await scheduler.init(onOpen: (id) => pendingNoteToOpen.value = id);
      final launched = await scheduler.launchNoteId();
      if (launched != null) pendingNoteToOpen.value = launched;
    } on Exception {
      // This platform can't show notifications; reminders stay in notes.
      _scheduler = null;
      return;
    }
    _repo = NotesRepository.instance..addListener(_sync);
    _sync();
  }

  Future<bool> requestPermission() async =>
      await _scheduler?.requestPermission() ?? false;

  /// Schedules [noteId]'s reminder again, e.g. so a renamed note's
  /// notification shows the new title.
  void refresh(String noteId) {
    final note = _repo?.byId(noteId);
    if (note != null && _isUpcoming(note)) _schedule(note);
  }

  bool _isUpcoming(Note note) {
    final at = note.remindAt;
    return at != null && !note.inTrash && at.isAfter(DateTime.now());
  }

  void _sync() {
    final repo = _repo;
    if (repo == null) return;
    final upcoming = {
      for (final note in repo.notes)
        if (_isUpcoming(note)) note.id: note,
    };
    for (final id in [..._scheduled.keys]) {
      if (!upcoming.containsKey(id)) {
        _scheduled.remove(id);
        _scheduler?.cancel(id);
      }
    }
    for (final note in upcoming.values) {
      if (_scheduled[note.id] != note.remindAt) _schedule(note);
    }
  }

  void _schedule(Note note) {
    _scheduled[note.id] = note.remindAt!;
    final firstLine = note.preview.split('\n').first.trim();
    _scheduler?.schedule(
      noteId: note.id,
      at: note.remindAt!,
      title: note.displayTitle,
      body: firstLine.isEmpty ? 'Reminder from Inkleaf' : firstLine,
    );
  }
}
