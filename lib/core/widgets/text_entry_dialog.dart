import 'package:flutter/material.dart';

/// Asks for a line (or, with [multiline], a few lines) of text. Resolves to
/// the entered text, or null if cancelled.
Future<String?> showTextEntryDialog(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
  bool multiline = false,
  String action = 'Save',
}) => showDialog<String>(
  context: context,
  builder: (_) => _TextEntryDialog(
    title: title,
    initial: initial,
    hint: hint,
    multiline: multiline,
    action: action,
  ),
);

class _TextEntryDialog extends StatefulWidget {
  const _TextEntryDialog({
    required this.title,
    required this.initial,
    required this.hint,
    required this.multiline,
    required this.action,
  });

  final String title;
  final String initial;
  final String? hint;
  final bool multiline;
  final String action;

  @override
  State<_TextEntryDialog> createState() => _TextEntryDialogState();
}

class _TextEntryDialogState extends State<_TextEntryDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        minLines: widget.multiline ? 3 : 1,
        maxLines: widget.multiline ? 8 : 1,
        keyboardType: widget.multiline
            ? TextInputType.multiline
            : TextInputType.text,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: widget.multiline ? null : (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: Text(widget.action)),
      ],
    );
  }
}
