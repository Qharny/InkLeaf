import 'package:flutter/material.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Today, 3:00 PM", "Tomorrow, 09:00", "Fri, 9:00 AM", "12 Mar, 9:00 AM",
/// in the phone's 12- or 24-hour style.
String reminderLabel(BuildContext context, DateTime at, {DateTime? now}) {
  now ??= DateTime.now();
  final time = MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(at),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  final today = DateTime(now.year, now.month, now.day);
  final days = DateTime(at.year, at.month, at.day).difference(today).inDays;
  final day = switch (days) {
    0 => 'Today',
    1 => 'Tomorrow',
    -1 => 'Yesterday',
    > 1 && < 7 => _weekdays[at.weekday - 1],
    _ =>
      '${at.day} ${_months[at.month - 1]}'
          '${at.year == now.year ? '' : ' ${at.year}'}',
  };
  return '$day, $time';
}

/// What the reminder sheet decided: a new time, or (with `at` null) to
/// remove the reminder. The sheet returns null when dismissed.
typedef ReminderChoice = ({DateTime? at});

/// Quick choices (later today, tomorrow morning, next week), a date and
/// time picker, and removing an existing reminder.
Future<ReminderChoice?> showReminderPicker(
  BuildContext context, {
  DateTime? current,
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final today = DateTime(at.year, at.month, at.day);
  final laterToday = DateTime(at.year, at.month, at.day, at.hour + 3);
  final tomorrow = today.add(const Duration(days: 1, hours: 9));
  final nextMonday = today.add(Duration(days: 8 - at.weekday, hours: 9));
  final quick = [
    // Only while "later today" is still a sensible time today.
    if (laterToday.day == at.day && laterToday.hour <= 21)
      ('Later today', Icons.schedule_rounded, laterToday),
    ('Tomorrow morning', Icons.wb_twilight_rounded, tomorrow),
    ('Next week', Icons.date_range_rounded, nextMonday),
  ];

  return showModalBottomSheet<ReminderChoice>(
    context: context,
    builder: (sheetContext) {
      Future<void> pick() async {
        final start = current ?? tomorrow;
        final date = await showDatePicker(
          context: sheetContext,
          initialDate: start.isBefore(today) ? today : start,
          firstDate: today,
          lastDate: today.add(const Duration(days: 365 * 5)),
        );
        if (date == null || !sheetContext.mounted) return;
        final time = await showTimePicker(
          context: sheetContext,
          initialTime: TimeOfDay.fromDateTime(start),
        );
        if (time == null || !sheetContext.mounted) return;
        final chosen = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        if (!chosen.isAfter(DateTime.now())) {
          ScaffoldMessenger.of(sheetContext).showSnackBar(
            const SnackBar(
              persist: false,
              duration: Duration(seconds: 3),
              content: Text('Pick a time in the future'),
            ),
          );
          return;
        }
        Navigator.of(sheetContext).pop((at: chosen));
      }

      // Scrolls on short screens (small phones, landscape) rather than
      // cutting off the last choices.
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  'Remind me',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              for (final (label, icon, time) in quick)
                ListTile(
                  leading: Icon(icon),
                  title: Text(label),
                  subtitle: Text(reminderLabel(sheetContext, time, now: at)),
                  onTap: () => Navigator.of(sheetContext).pop((at: time)),
                ),
              ListTile(
                leading: const Icon(Icons.edit_calendar_outlined),
                title: const Text('Pick a date and time'),
                onTap: pick,
              ),
              if (current != null)
                ListTile(
                  leading: const Icon(Icons.notifications_off_outlined),
                  title: const Text('Remove reminder'),
                  onTap: () => Navigator.of(sheetContext).pop((at: null)),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}
