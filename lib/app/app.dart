import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/storage/app_prefs.dart';
import '../features/lock/presentation/lock_gate.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class InkleafApp extends StatefulWidget {
  const InkleafApp({super.key});

  @override
  State<InkleafApp> createState() => _InkleafAppState();
}

class _InkleafAppState extends State<InkleafApp> {
  late final GoRouter _router = createRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AppPrefs.instance.themeMode,
      builder: (context, themeMode, _) => MaterialApp.router(
        title: 'Inkleaf',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        routerConfig: _router,
        builder: (context, child) => LockGate(child: child!),
      ),
    );
  }
}
