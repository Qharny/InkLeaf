import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../data/notes_repository.dart';
import '../domain/note.dart';

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

String _day(DateTime d) =>
    '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

/// A ready-made starting point for a new note.
class NoteTemplate {
  const NoteTemplate({
    required this.name,
    required this.description,
    required this.icon,
    required this.build,
  });

  final String name;
  final String description;
  final IconData icon;

  /// The new note, from a fresh empty one.
  final Note Function(Note blank, DateTime now) build;
}

List<ChecklistItem> _items(List<String> texts) => [
  for (final t in texts) ChecklistItem.create().copyWith(text: t),
];

final noteTemplates = [
  NoteTemplate(
    name: 'Daily journal',
    description: 'Gratitude, today and tomorrow',
    icon: Icons.auto_stories_outlined,
    build: (n, now) => n.copyWith(
      title: 'Journal · ${_day(now)}',
      tags: ['journal'],
      body:
          '## Grateful for\n- \n\n'
          '## Today\n\n\n'
          '## Tomorrow I want to\n- ',
    ),
  ),
  NoteTemplate(
    name: 'Meeting notes',
    description: 'Who, what, and the actions that came out of it',
    icon: Icons.groups_outlined,
    build: (n, now) => n.copyWith(
      title: 'Meeting · ${_day(now)}',
      tags: ['meeting'],
      body: '**With:** \n\n## Agenda\n- \n\n## Notes\n',
      checklist: [ChecklistItem.create()],
    ),
  ),
  NoteTemplate(
    name: 'Packing list',
    description: 'The usual things, ready to tick off',
    icon: Icons.luggage_outlined,
    build: (n, now) => n.copyWith(
      title: 'Packing list',
      tags: ['travel'],
      checklist: _items([
        'Passport or ID',
        'Phone charger',
        'Toothbrush',
        'Medicines',
        'Clothes',
        'Headphones',
      ]),
    ),
  ),
  NoteTemplate(
    name: 'Recipe',
    description: 'Ingredients to tick off, then the steps',
    icon: Icons.restaurant_outlined,
    build: (n, now) => n.copyWith(
      title: 'Recipe',
      tags: ['recipes'],
      body: '**Serves:**  · **Time:** \n\n## Steps\n1. \n2. \n3. ',
      checklist: [ChecklistItem.create(), ChecklistItem.create()],
    ),
  ),
  NoteTemplate(
    name: 'To-do',
    description: 'A plain checklist',
    icon: Icons.checklist_rounded,
    build: (n, now) =>
        n.copyWith(title: 'To-do', checklist: [ChecklistItem.create()]),
  ),
];

/// Lets the user pick a template, then creates that note and opens it.
Future<void> showTemplatePicker(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        void use(NoteTemplate template) {
          final repo = NotesRepository.instance;
          final note = template.build(
            Note.create(color: repo.notes.length % 5),
            DateTime.now(),
          );
          repo.save(note);
          Navigator.of(sheetContext).pop();
          context.push(AppRoutes.noteById(note.id));
        }

        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text(
                    'Start from a template',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                ),
                for (final template in noteTemplates)
                  ListTile(
                    leading: Icon(template.icon),
                    title: Text(template.name),
                    subtitle: Text(template.description),
                    onTap: () => use(template),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
