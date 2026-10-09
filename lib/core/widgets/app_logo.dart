import 'package:flutter/material.dart';

import '../../app/theme/sketch_styles.dart';

/// The Inkleaf notebook-and-leaf logo, optionally with the hand-lettered
/// wordmark beside it.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40, this.showName = false});

  static const asset = 'assets/images/logo.png';

  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final mark = Image.asset(
      asset,
      width: size,
      height: size,
      semanticLabel: showName ? null : 'Inkleaf',
      filterQuality: FilterQuality.medium,
    );
    if (!showName) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: size * 0.25),
        MarkerHighlight(
          child: Text(
            'Inkleaf',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontSize: size * 0.7),
          ),
        ),
      ],
    );
  }
}
