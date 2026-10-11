import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/sketch_styles.dart';
import '../../../core/utils/relative_time.dart';
import '../../canvas/presentation/board_painters.dart';
import '../../reminders/presentation/reminder_picker.dart';
import '../domain/note.dart';

/// The pastel paper fill for a note color index. On the night desk the
/// pastel is reduced to a tint so text keeps its contrast.
Color noteFill(BuildContext context, int color) {
  final pastel = AppColors.notes[color % AppColors.notes.length];
  final scheme = Theme.of(context).colorScheme;
  return scheme.brightness == Brightness.light
      ? pastel
      : Color.alphaBlend(pastel.withValues(alpha: 0.14), scheme.surface);
}

/// A note on the desk: pastel card with a pencil outline, title, preview,
/// tags and when it was last edited.
class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    this.onTap,
    this.onLongPress,
    this.previewLines = 4,
    this.fixedHeight = true,
  });

  final Note note;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final int previewLines;

  /// Whether the parent gives the card a fixed height (grid, pinned row), so
  /// the footer is pushed to the bottom. In lists the card sizes to content.
  final bool fixedHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final preview = note.preview;
    final listed = [
      for (final i in note.checklist)
        if (i.text.trim().isNotEmpty) i,
    ];
    // With no text to preview, show the first few checklist items instead
    // (they take the place of a sketch thumbnail).
    final showItems = preview.isEmpty ? listed.take(3).toList() : const [];
    final showSketch =
        preview.isEmpty && listed.isEmpty && note.sketch.isNotEmpty;
    final sketch = Semantics(
      label: 'Sketch',
      child: CustomPaint(
        painter: SketchPainter(strokes: note.sketch, ink: scheme.onSurface),
      ),
    );
    final previewText = Text(
      preview,
      style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      maxLines: previewLines,
      overflow: TextOverflow.ellipsis,
    );

    return Material(
      color: noteFill(context, note.color),
      shape: SketchBorder(
        side: BorderSide(
          color: scheme.outline,
          width: SketchStyles.strokeWidth,
        ),
        seed: note.id.hashCode,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
          child: Column(
            mainAxisSize: fixedHeight ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      note.displayTitle,
                      style: text.titleLarge?.copyWith(fontSize: 18),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (note.pinned)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 2),
                      child: Icon(
                        Icons.push_pin_rounded,
                        size: 18,
                        semanticLabel: 'Pinned',
                        color: scheme.onSurface,
                      ),
                    ),
                ],
              ),
              if (note.remindAt case final at? when at.isAfter(DateTime.now()))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_active_outlined,
                        size: 16,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          reminderLabel(context, at),
                          style: text.labelMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          semanticsLabel:
                              'Reminder ${reminderLabel(context, at)}',
                        ),
                      ),
                    ],
                  ),
                ),
              if (note.scanFile != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.document_scanner_outlined,
                        size: 16,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Scanned page',
                          style: text.labelMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              if (note.audio case final audio?)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.mic_none_rounded,
                        size: 16,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          formatDuration(audio.duration),
                          style: text.labelMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                          semanticsLabel:
                              'Recording, ${formatDuration(audio.duration)}',
                        ),
                      ),
                    ],
                  ),
                ),
              if (listed.isNotEmpty) ...[
                for (final item in showItems)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Icon(
                          item.done
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          size: 16,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            item.text,
                            style: text.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              decoration: item.done
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${listed.where((i) => i.done).length}/${listed.length} done',
                    style: text.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 4),
                if (fixedHeight) Flexible(child: previewText) else previewText,
              ] else if (showSketch) ...[
                const SizedBox(height: 4),
                if (fixedHeight)
                  Expanded(child: sketch)
                else
                  SizedBox(height: 90, width: double.infinity, child: sketch),
              ],
              if (fixedHeight && !showSketch) const Spacer(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.tags.map((t) => '#$t').join('  '),
                      style: text.labelMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    relativeTime(note.updatedAt),
                    style: text.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row of pastel swatches for picking a note color.
class NoteColorPicker extends StatelessWidget {
  const NoteColorPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  static const _names = ['Yellow', 'Blue', 'Green', 'Pink', 'Purple'];

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.outline;
    return Wrap(
      spacing: 4,
      children: [
        for (var i = 0; i < AppColors.notes.length; i++)
          Semantics(
            label: _names[i],
            selected: i == selected,
            button: true,
            child: InkResponse(
              onTap: () => onSelected(i),
              radius: 24,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: ShapeDecoration(
                    color: AppColors.notes[i],
                    shape: SketchBorder(
                      side: BorderSide(
                        color: ink,
                        width: i == selected ? 2.6 : 1.2,
                      ),
                      radius: 18,
                      seed: i,
                      passes: 1,
                    ),
                  ),
                  child: i == selected
                      ? const Icon(Icons.check_rounded, color: AppColors.ink)
                      : null,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
