import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/theme/sketch_styles.dart';
import '../../../core/storage/media_store.dart';

/// A scanned page: tap to see it full screen and zoom in.
class ScanPreview extends StatelessWidget {
  const ScanPreview({
    super.key,
    required this.fileName,
    this.height = 220,
    this.onRemove,
  });

  /// File name inside `MediaStore.scans`.
  final String fileName;
  final double height;

  /// Shows a remove button when set.
  final VoidCallback? onRemove;

  File get _file => File(MediaStore.scans.pathOf(fileName));

  void _openViewer(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 5,
                child: Image.file(
                  _file,
                  fit: BoxFit.contain,
                  semanticLabel: 'Scanned page',
                  errorBuilder: (_, _, _) => const _Missing(onDark: true),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton.filledTonal(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final remove = onRemove;
    return Material(
      color: scheme.surfaceContainerHigh,
      shape: SketchBorder(
        side: BorderSide(color: scheme.outline, width: 1.2),
        seed: fileName.hashCode,
        passes: 1,
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              button: true,
              label: 'Scanned page. Tap to view',
              child: InkWell(
                onTap: () => _openViewer(context),
                child: Image.file(
                  _file,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const _Missing(),
                ),
              ),
            ),
            if (remove != null)
              Positioned(
                top: 6,
                right: 6,
                child: IconButton.filledTonal(
                  tooltip: 'Remove photo',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: remove,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing({this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final color = onDark
        ? Colors.white70
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: color, size: 36),
          const SizedBox(height: 4),
          Text(
            'Photo unavailable',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
