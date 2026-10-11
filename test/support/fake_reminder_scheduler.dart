import 'package:flutter/foundation.dart';
import 'package:my_note/features/reminders/data/reminders.dart';

/// Records reminders instead of asking the phone to show them.
class FakeReminderScheduler implements ReminderScheduler {
  FakeReminderScheduler({this.allowed = true, this.launchedBy});

  final bool allowed;
  final String? launchedBy;

  /// Scheduled reminders by note id: (when, title).
  final scheduled = <String, (DateTime, String)>{};
  ValueChanged<String>? onOpen;

  /// Pretends the user tapped [noteId]'s notification.
  void tap(String noteId) => onOpen?.call(noteId);

  @override
  Future<void> init({required ValueChanged<String> onOpen}) async =>
      this.onOpen = onOpen;

  @override
  Future<bool> requestPermission() async => allowed;

  @override
  Future<void> schedule({
    required String noteId,
    required DateTime at,
    required String title,
    required String body,
  }) async => scheduled[noteId] = (at, title);

  @override
  Future<void> cancel(String noteId) async => scheduled.remove(noteId);

  @override
  Future<String?> launchNoteId() async => launchedBy;
}
