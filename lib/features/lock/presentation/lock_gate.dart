import 'package:flutter/material.dart';

import '../../../app/theme/sketch_styles.dart';
import '../../../core/widgets/app_logo.dart';
import '../data/app_lock.dart';

/// Covers the app while it's locked. Notes underneath aren't drawn (and
/// can't be reached) until the phone confirms it's you; their state is kept.
class LockGate extends StatelessWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AppLock.instance.locked,
      builder: (context, locked, child) => Stack(
        children: [
          Offstage(
            offstage: locked,
            child: TickerMode(enabled: !locked, child: child!),
          ),
          if (locked) const _LockScreen(),
        ],
      ),
      child: child,
    );
  }
}

class _LockScreen extends StatefulWidget {
  const _LockScreen();

  @override
  State<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<_LockScreen> {
  @override
  void initState() {
    super.initState();
    // Ask straight away; the button is there if that's dismissed.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AppLock.instance.unlock(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogo(size: 96),
                const SizedBox(height: 24),
                MarkerHighlight(
                  child: Text('Inkleaf is locked', style: text.headlineSmall),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use your fingerprint, face or screen lock to open your '
                  'notebook.',
                  style: text.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: AppLock.instance.unlock,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: const Text('Unlock'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
