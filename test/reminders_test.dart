import 'package:flutter_test/flutter_test.dart';
import 'package:my_note/core/storage/app_database.dart';
import 'package:my_note/features/notes/data/notes_repository.dart';
import 'package:my_note/features/notes/domain/note.dart';
import 'package:my_note/features/reminders/data/reminders.dart';

import 'support/fake_reminder_scheduler.dart';

void main() {
  late FakeReminderScheduler scheduler;
  late NotesRepository repo;
  final soon = DateTime.now().add(const Duration(days: 1));

  Note note(String id, {DateTime? at, String title = 'Call mum'}) => Note(
    id: id,
    title: title,
    remindAt: at,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUp(() async {
    AppDatabase.openInMemory();
    await NotesRepository.init();
    repo = NotesRepository.instance;
    scheduler = FakeReminderScheduler();
    await Reminders.instance.init(scheduler);
  });

  test('setting, moving and clearing a reminder follow the note', () {
    repo.save(note('a', at: soon));
    expect(scheduler.scheduled['a'], (soon, 'Call mum'));

    final later = soon.add(const Duration(hours: 2));
    repo.save(note('a', at: later));
    expect(scheduler.scheduled['a']!.$1, later);

    repo.save(note('a'));
    expect(scheduler.scheduled, isEmpty);
  });

  test('trash cancels, restore brings it back, delete cancels', () {
    repo.save(note('a', at: soon));
    repo.moveToTrash('a');
    expect(scheduler.scheduled, isEmpty);
    repo.restore('a');
    expect(scheduler.scheduled.keys, ['a']);
    repo.delete('a');
    expect(scheduler.scheduled, isEmpty);
  });

  test('past reminders are not scheduled', () {
    repo.save(note('a', at: DateTime.now().subtract(const Duration(hours: 1))));
    expect(scheduler.scheduled, isEmpty);
  });

  test('every upcoming reminder is scheduled again at launch', () async {
    repo.save(note('a', at: soon));
    final fresh = FakeReminderScheduler();
    await Reminders.instance.init(fresh);
    expect(fresh.scheduled.keys, ['a']);
  });

  test('refresh picks up a new title', () {
    repo.save(note('a', at: soon));
    repo.save(note('a', at: soon, title: 'Call dad'));
    expect(scheduler.scheduled['a']!.$2, 'Call mum', reason: 'same time');
    Reminders.instance.refresh('a');
    expect(scheduler.scheduled['a']!.$2, 'Call dad');
  });

  test('notification ids are stable, positive and differ per note', () {
    expect(reminderIdFor('abc'), reminderIdFor('abc'));
    expect(reminderIdFor('abc'), isNot(reminderIdFor('abd')));
    expect(reminderIdFor('abc'), greaterThanOrEqualTo(0));
    expect(reminderIdFor('abc'), lessThan(1 << 31));
  });
}
