import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/sketch_styles.dart';
import 'board_painters.dart';

/// Pen colors. [AppColors.ink] follows the theme (see [strokeColor]).
const penColors = [
  AppColors.ink,
  AppColors.sageDeep,
  Color(0xFFC0563B), // terracotta
  Color(0xFF3F67A8), // blue ink
  AppColors.pencilDeep,
];

const penWidths = [2.0, 4.0, 8.0];

/// A floating, pencil-outlined tool strip.
class ToolBar extends StatelessWidget {
  const ToolBar({super.key, required this.children, this.seed = 2});

  final List<Widget> children;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: SketchBorder(
        side: BorderSide(
          color: scheme.outline,
          width: SketchStyles.strokeWidth,
        ),
        radius: 22,
        seed: seed,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

class ToolBarDivider extends StatelessWidget {
  const ToolBarDivider({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: 1.4,
    height: 28,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: Theme.of(context).colorScheme.outlineVariant,
  );
}

/// An icon button that shows a marker highlight while [selected].
class ToolButton extends StatelessWidget {
  const ToolButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
  });

  final Widget icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    isSelected: selected,
    style: selected
        ? IconButton.styleFrom(backgroundColor: AppColors.markerYellow)
        : null,
    icon: icon,
    onPressed: onPressed,
  );
}

/// One pen color to pick.
class PenSwatch extends StatelessWidget {
  const PenSwatch({
    super.key,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  /// The stored color; ink is shown in the theme's text color.
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shown = strokeColor(
      color.toARGB32(),
      Theme.of(context).colorScheme.onSurface,
    );
    return Semantics(
      label: 'Pen color',
      selected: selected,
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: Container(
              width: selected ? 28 : 22,
              height: selected ? 28 : 22,
              decoration: BoxDecoration(
                color: shown,
                shape: BoxShape.circle,
                border: selected
                    ? Border.all(
                        color: Theme.of(context).colorScheme.surface,
                        width: 3,
                      )
                    : null,
                boxShadow: selected
                    ? [BoxShadow(color: shown, spreadRadius: 2)]
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The color swatches and widths for a pen, as children for a [ToolBar].
List<Widget> penOptions({
  required BuildContext context,
  required Color color,
  required double width,
  required ValueChanged<Color> onColor,
  required ValueChanged<double> onWidth,
}) {
  final shown = strokeColor(
    color.toARGB32(),
    Theme.of(context).colorScheme.onSurface,
  );
  return [
    for (final c in penColors)
      PenSwatch(color: c, selected: c == color, onTap: () => onColor(c)),
    const ToolBarDivider(),
    for (final w in penWidths)
      ToolButton(
        tooltip: switch (w) {
          2.0 => 'Fine pen',
          4.0 => 'Medium pen',
          _ => 'Thick pen',
        },
        selected: w == width,
        onPressed: () => onWidth(w),
        icon: Container(
          width: 22,
          height: w + 1,
          decoration: BoxDecoration(
            color: shown,
            borderRadius: BorderRadius.circular(w),
          ),
        ),
      ),
  ];
}
