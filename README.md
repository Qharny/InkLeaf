<p align="center">
  <img src="assets/images/logo.png" alt="Inkleaf logo" width="140">
</p>

<h1 align="center">Inkleaf</h1>

<p align="center"><em>Ideas today, progress tomorrow.</em></p>

<p align="center">
  A warm, hand-drawn digital notebook. Capture anything, connect your thoughts,
  and find them again whenever you need them.
</p>

---

## About

Inkleaf is a Flutter note-taking app that feels like opening a physical
sketchbook: cream paper, charcoal ink, pencil outlines and little doodles,
without giving up the speed and searchability of a digital tool.

The plan is for Inkleaf to support:

- **Quick capture.** Write a thought without choosing a folder first.
- **Smart scanning (OCR).** Turn photos of pages into editable, searchable text.
- **Visual canvas.** Arrange notes, draw arrows and connect ideas.
- **Full-text search.** Search typed notes and the text inside scans.
- **Offline first.** Core note-taking works without a connection.

## Status

Early development (Phase 1: Foundation).

| Area | Status |
|---|---|
| Sketchbook theme, colors and typography | ✅ Done |
| Navigation and routing | ✅ Done |
| Splash screen and onboarding | ✅ Done |
| App icon and native splash | ✅ Done |
| Home, note editor, search, canvas, collections | 🚧 Placeholder screens |
| Local database and note CRUD | ⏳ Planned |
| OCR scanner | ⏳ Planned |

## Design

The look follows the hand-drawn concept in `assets/`.

| Role | Color | Hex |
|---|---|---|
| Paper | Warm cream | `#F6F0E3` |
| Ink | Soft charcoal | `#292B28` |
| Accent | Sage green | `#789477` |
| Highlight | Pencil yellow | `#E8C875` |

- **Type:** [Kalam](https://fonts.google.com/specimen/Kalam) for headings and
  [Patrick Hand](https://fonts.google.com/specimen/Patrick+Hand) for body text.
- **Shapes:** slightly wobbly double "pencil" outlines (`SketchBorder`) on
  cards, buttons, dialogs and chips.
- **Decorations:** marker highlights behind key words (`MarkerHighlight`),
  hand-drawn dividers, and spark, leaf and squiggle doodles from the logo.
- **Accessibility:** 48px+ touch targets, readable contrast, and animations
  are skipped when the device's reduce-motion setting is on.

## Navigation

| Route | Screen |
|---|---|
| `/splash` | Animated splash (start screen) |
| `/onboarding` | Four-page intro, shown on first run only |
| `/home`, `/search`, `/canvas`, `/collections` | Bottom-navigation tabs |
| `/notes/new` (`?mode=draw` or `?mode=record`) | New note |
| `/notes/:noteId` | Note editor |
| `/scan` | Document scanner |
| `/collections/:id`, `/canvas/:id` | A single collection or canvas |
| `/settings`, `/trash` | Secondary menu (⋮) |

The **+** button in the bottom bar opens a quick menu with New note, Scan
document, Draw and Record. Use the helpers in `AppRoutes` (for example
`AppRoutes.noteById(id)`) instead of typing paths by hand.

## Project structure

```
lib/
├── app/
│   ├── app.dart               # InkleafApp (MaterialApp.router)
│   ├── app_shell.dart         # Bottom nav, + menu, secondary menu
│   ├── router.dart            # go_router routes and AppRoutes
│   └── theme/
│       ├── app_colors.dart    # Palette
│       ├── app_theme.dart     # Light and dark ThemeData
│       └── sketch_styles.dart # SketchBorder, MarkerHighlight, SketchDivider
├── core/
│   ├── storage/app_prefs.dart # First-run flag
│   └── widgets/               # AppLogo, doodles, placeholder screen
├── features/
│   ├── onboarding/
│   └── splash/
└── main.dart
```

## Tech stack

| Layer | Choice |
|---|---|
| Framework | Flutter + Dart |
| Routing | [go_router](https://pub.dev/packages/go_router) |
| Fonts | [google_fonts](https://pub.dev/packages/google_fonts) |
| Preferences | [shared_preferences](https://pub.dev/packages/shared_preferences) |
| Icons and splash | flutter_launcher_icons, flutter_native_splash |
| Planned | Riverpod, Drift + SQLite (FTS5), Google ML Kit text recognition |

## Getting started

Requirements: Flutter (stable channel) with Dart 3.13 or newer.

```bash
git clone https://github.com/Qharny/InkLeaf.git
cd InkLeaf
flutter pub get
flutter run
```

Fonts download the first time the app runs, so the first launch needs an
internet connection.

To see onboarding again, clear the app's data or reinstall it.

### Tests and checks

```bash
flutter analyze
flutter test
```

### Regenerating the app icon and splash

After changing the images in `assets/icon/`:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## Author

Built by [Qharny](https://github.com/Qharny).
