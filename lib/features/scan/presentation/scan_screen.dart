import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/sketch_styles.dart';
import '../../../core/storage/media_store.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/domain/note.dart';
import '../../notes/presentation/scan_preview.dart';
import '../data/page_scanner.dart';

enum _Step { choose, reading, review }

/// "Capture anything": photograph a page (or pick a photo), read its text
/// on the device, fix it up, and save both as a note.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _scanner = PageScanner.create();
  final _text = TextEditingController();
  _Step _step = _Step.choose;

  /// The photo, once copied into the scans folder.
  String? _fileName;
  String? _error;
  bool _saved = false;

  @override
  void dispose() {
    _scanner.dispose();
    _text.dispose();
    // A scan that was never saved shouldn't linger on the device.
    final name = _fileName;
    if (!_saved && name != null) MediaStore.scans.delete(name);
    super.dispose();
  }

  Future<void> _capture({required bool camera}) async {
    String? picked;
    try {
      picked = await _scanner.pickImage(camera: camera);
    } on Exception {
      setState(
        () => _error = camera
            ? "Couldn't open the camera."
            : "Couldn't open your photos.",
      );
      return;
    }
    if (picked == null || !mounted) return;

    final previous = _fileName;
    if (previous != null) MediaStore.scans.delete(previous);
    final name = MediaStore.scans.importFile(picked);
    setState(() {
      _fileName = name;
      _error = null;
      _step = _Step.reading;
    });

    var text = '';
    try {
      text = await _scanner.recognize(MediaStore.scans.pathOf(name));
    } on Exception {
      _error = "Couldn't read text from this photo. You can still save it.";
    }
    if (!mounted) return;
    _text.text = text;
    setState(() => _step = _Step.review);
  }

  void _save() {
    final name = _fileName;
    if (name == null) return;
    _saved = true;
    final repo = NotesRepository.instance;
    final note = Note.create(color: repo.notes.length % AppColors.notes.length)
        .copyWith(body: _text.text.trim(), scanFile: () => name);
    repo.save(note);
    context.pushReplacement(AppRoutes.noteById(note.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan')),
      body: SafeArea(
        child: switch (_step) {
          _Step.choose => _buildChoose(context),
          _Step.reading => _buildReading(context),
          _Step.review => _buildReview(context),
        },
      ),
    );
  }

  Widget _buildChoose(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.document_scanner_outlined, size: 72),
            const SizedBox(height: 20),
            MarkerHighlight(
              child: Text('Capture anything', style: text.headlineSmall),
            ),
            const SizedBox(height: 8),
            Text(
              'Snap a page, a whiteboard or a receipt. Inkleaf reads the text '
              'on your phone, so you can edit it and find it later.',
              style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => _capture(camera: true),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Take a photo'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _capture(camera: false),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose from gallery'),
            ),
            if (_error case final error?) ...[
              const SizedBox(height: 16),
              Text(
                error,
                style: text.bodyMedium?.copyWith(color: scheme.error),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReading(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ScanPreview(fileName: _fileName!, height: 280),
          const SizedBox(height: 24),
          const LinearProgressIndicator(),
          const SizedBox(height: 12),
          Text('Reading text…', style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildReview(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final found = _text.text.isNotEmpty;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ScanPreview(fileName: _fileName!),
              const SizedBox(height: 16),
              Text(
                found ? 'Text found' : 'No text found',
                style: text.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                _error ??
                    (found
                        ? 'Fix anything it misread before saving.'
                        : 'You can still save the photo, and type a note '
                              'to go with it.'),
                style: text.bodyMedium?.copyWith(
                  color: _error != null
                      ? scheme.error
                      : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _text,
                minLines: 6,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Text from the page',
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() => _step = _Step.choose),
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Retake'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Save as note'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
