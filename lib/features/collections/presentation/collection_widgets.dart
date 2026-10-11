import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/sketch_styles.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/domain/note.dart';
import '../data/collections_repository.dart';
import '../domain/collection.dart';

const _coverNames = ['Sage', 'Pencil', 'Terracotta', 'Blue', 'Lilac', 'Kraft'];

Color coverColor(int cover) =>
    AppColors.covers[cover % AppColors.covers.length];

/// Notes in [collection] that still exist outside the trash, most recently
/// edited first.
List<Note> liveNotesIn(Collection collection) {
  final repo = NotesRepository.instance;
  return [
    for (final id in collection.noteIds)
      if (repo.byId(id) case final note? when !note.inTrash) note,
  ]..sort(NoteSort.edited.compare);
}

/// "3 notes", "1 note", "No notes yet".
String noteCountLabel(int count) => switch (count) {
  0 => 'No notes yet',
  1 => '1 note',
  _ => '$count notes',
};

/// What the collection form returns.
typedef CollectionDetails = ({String name, String description, int cover});

/// Asks for a collection's name, description and cover. Pre-filled from
/// [existing] when editing.
Future<CollectionDetails?> showCollectionForm(
  BuildContext context, {
  Collection? existing,
}) => showDialog<CollectionDetails>(
  context: context,
  builder: (_) => _CollectionForm(existing: existing),
);

class _CollectionForm extends StatefulWidget {
  const _CollectionForm({this.existing});

  final Collection? existing;

  @override
  State<_CollectionForm> createState() => _CollectionFormState();
}

class _CollectionFormState extends State<_CollectionForm> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _description = TextEditingController(
    text: widget.existing?.description,
  );
  late int _cover =
      widget.existing?.cover ??
      CollectionsRepository.instance.collections.length %
          AppColors.covers.length;
  bool _showError = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    Navigator.of(
      context,
    ).pop((name: name, description: _description.text.trim(), cover: _cover));
  }

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.outline;
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'New collection' : 'Edit collection',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: widget.existing == null,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Recipes',
                errorText: _showError ? 'Give it a name' : null,
              ),
              onChanged: (_) {
                if (_showError) setState(() => _showError = false);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
            ),
            const SizedBox(height: 16),
            Text('Cover', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Wrap(
              children: [
                for (var i = 0; i < AppColors.covers.length; i++)
                  Semantics(
                    label: '${_coverNames[i]} cover',
                    selected: i == _cover,
                    button: true,
                    child: InkResponse(
                      onTap: () => setState(() => _cover = i),
                      radius: 24,
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: ShapeDecoration(
                            color: AppColors.covers[i],
                            shape: SketchBorder(
                              side: BorderSide(
                                color: ink,
                                width: i == _cover ? 2.6 : 1.2,
                              ),
                              radius: 8,
                              seed: i + 20,
                              passes: 1,
                            ),
                          ),
                          child: i == _cover
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: AppColors.ink,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(widget.existing == null ? 'Create' : 'Save'),
        ),
      ],
    );
  }
}

/// Lets the user choose which collections the note [noteId] is in, and
/// create a new one on the spot.
Future<void> showCollectionPicker(BuildContext context, String noteId) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CollectionPickerSheet(noteId: noteId),
    );

class _CollectionPickerSheet extends StatefulWidget {
  const _CollectionPickerSheet({required this.noteId});

  final String noteId;

  @override
  State<_CollectionPickerSheet> createState() => _CollectionPickerSheetState();
}

class _CollectionPickerSheetState extends State<_CollectionPickerSheet> {
  final _repo = CollectionsRepository.instance;
  late final Set<String> _selected = {
    for (final c in _repo.containing(widget.noteId)) c.id,
  };

  Future<void> _create() async {
    final details = await showCollectionForm(context);
    if (details == null) return;
    final created = Collection.create(
      name: details.name,
      description: details.description,
      cover: details.cover,
    );
    _repo.save(created);
    setState(() => _selected.add(created.id));
  }

  void _done() {
    _repo.setMembership(widget.noteId, _selected);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: ListenableBuilder(
          listenable: _repo,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
                child: Text('Add to collections', style: text.titleLarge),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final c in _repo.collections)
                      CheckboxListTile(
                        value: _selected.contains(c.id),
                        onChanged: (on) => setState(
                          () => on!
                              ? _selected.add(c.id)
                              : _selected.remove(c.id),
                        ),
                        secondary: Icon(
                          Icons.book_rounded,
                          color: coverColor(c.cover),
                        ),
                        title: Text(c.name),
                      ),
                    ListTile(
                      leading: const Icon(Icons.add_rounded),
                      title: const Text('New collection'),
                      onTap: _create,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: FilledButton(
                  onPressed: _done,
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
