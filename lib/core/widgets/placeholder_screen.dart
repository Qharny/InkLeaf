import 'package:flutter/material.dart';

import '../../app/theme/sketch_styles.dart';

/// Temporary stand-in for feature screens until they are built.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    this.subtitle,
    this.showAppBar = true,
    this.actions,
    this.appBarTitle,
  });

  final String title;
  final String? subtitle;
  final bool showAppBar;
  final List<Widget>? actions;

  /// Replaces the plain [title] text in the app bar, e.g. with the logo.
  final Widget? appBarTitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final body = Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MarkerHighlight(
              child: Text(
                title,
                style: text.displaySmall,
                textAlign: TextAlign.center,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: text.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );

    if (!showAppBar) return SafeArea(child: body);
    return Scaffold(
      appBar: AppBar(title: appBarTitle ?? Text(title), actions: actions),
      body: body,
    );
  }
}
