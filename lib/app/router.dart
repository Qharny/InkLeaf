import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/placeholder_screen.dart';
import '../features/canvas/presentation/canvas_editor_screen.dart';
import '../features/canvas/presentation/canvas_list_screen.dart';
import '../features/collections/presentation/collection_detail_screen.dart';
import '../features/collections/presentation/collections_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/notes/presentation/note_editor_screen.dart';
import '../features/notes/presentation/trash_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import 'app_shell.dart';

/// Route paths and helpers. Use these instead of string literals.
abstract final class AppRoutes {
  // First run.
  static const splash = '/splash';
  static const onboarding = '/onboarding';

  // Bottom-navigation tabs.
  static const home = '/home';
  static const search = '/search';
  static const canvas = '/canvas';
  static const collections = '/collections';

  // Full-screen routes (shown above the bottom navigation).
  static const newNote = '/notes/new';
  static const note = '/notes/:noteId';
  static const scan = '/scan';
  static const settings = '/settings';
  static const trash = '/trash';

  static String noteById(String id) => '/notes/$id';
  static String collectionById(String id) => '$collections/$id';
  static String canvasById(String id) => '$canvas/$id';

  /// New note in a given mode, e.g. `newNoteWith(NoteMode.draw)`.
  static String newNoteWith(NoteMode mode) =>
      mode == NoteMode.text ? newNote : '$newNote?mode=${mode.name}';

  /// New text note that is added to collection [collectionId] once written.
  static String newNoteIn(String collectionId) =>
      '$newNote?collection=$collectionId';
}

/// How a new note opens from the + menu.
enum NoteMode {
  text,
  draw,
  record;

  static NoteMode parse(String? value) =>
      NoteMode.values.asNameMap()[value] ?? NoteMode.text;
}

/// Builds the app's router. Each [InkleafApp] owns one, so state never
/// leaks between app instances (e.g. across widget tests).
GoRouter createRouter() {
  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(path: '/', redirect: (_, _) => AppRoutes.splash),
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: AppRoutes.onboarding,
        pageBuilder: (_, state) => _fadePage(state, const OnboardingScreen()),
      ),
      StatefulShellRoute.indexedStack(
        pageBuilder: (context, state, shell) =>
            _fadePage(state, AppShell(shell: shell)),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (_, _) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.search,
                builder: (_, state) =>
                    SearchScreen(initialQuery: state.uri.queryParameters['q']),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.canvas,
                builder: (_, _) => const CanvasListScreen(),
                routes: [
                  GoRoute(
                    path: ':canvasId',
                    parentNavigatorKey: rootKey,
                    builder: (_, state) => CanvasEditorScreen(
                      boardId: state.pathParameters['canvasId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.collections,
                builder: (_, _) => const CollectionsScreen(),
                routes: [
                  GoRoute(
                    path: ':collectionId',
                    builder: (_, state) => CollectionDetailScreen(
                      collectionId: state.pathParameters['collectionId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // Must be declared before /notes/:noteId so "new" isn't read as an id.
      GoRoute(
        path: AppRoutes.newNote,
        parentNavigatorKey: rootKey,
        builder: (_, state) =>
            switch (NoteMode.parse(state.uri.queryParameters['mode'])) {
              NoteMode.text => NoteEditorScreen(
                collectionId: state.uri.queryParameters['collection'],
              ),
              final mode => PlaceholderScreen(
                title: 'New note',
                subtitle: mode.name,
              ),
            },
      ),
      GoRoute(
        path: AppRoutes.note,
        parentNavigatorKey: rootKey,
        builder: (_, state) =>
            NoteEditorScreen(noteId: state.pathParameters['noteId']),
      ),
      GoRoute(
        path: AppRoutes.scan,
        parentNavigatorKey: rootKey,
        pageBuilder: (_, state) => MaterialPage(
          key: state.pageKey,
          fullscreenDialog: true,
          child: const PlaceholderScreen(title: 'Capture anything'),
        ),
      ),
      GoRoute(
        path: AppRoutes.settings,
        parentNavigatorKey: rootKey,
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.trash,
        parentNavigatorKey: rootKey,
        builder: (_, _) => const TrashScreen(),
      ),
    ],
    errorBuilder: (_, state) => PlaceholderScreen(
      title: 'Page not found',
      subtitle: state.uri.toString(),
    ),
  );
}

/// Soft cross-fade, used when leaving the splash so the paper doesn't "slide".
CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) =>
    CustomTransitionPage(
      key: state.pageKey,
      transitionDuration: const Duration(milliseconds: 400),
      child: child,
      transitionsBuilder: (_, animation, _, child) => FadeTransition(
        opacity: CurveTween(curve: Curves.easeOut).animate(animation),
        child: child,
      ),
    );
