# Contributing to Inkleaf

Thanks for wanting to help. Inkleaf is a small, local-first notebook, and
every kind of help counts, not just code.

## Ways to help without writing code

- **Report a bug.** [Open an issue](https://github.com/Qharny/InkLeaf/issues/new)
  and say what you did, what you expected, and what happened instead. Your
  phone model and Android version help a lot. A screenshot or screen
  recording helps even more.
- **Suggest an idea.** Open an issue describing the problem you'd like
  solved, not only the feature. "I lose track of shopping lists" is more
  useful than "add a shopping mode".
- **Try a test build.** Install the latest APK from
  [Releases](https://github.com/Qharny/InkLeaf/releases) and tell us what
  feels off.
- **Improve the words.** Typos, confusing labels and unclear docs are all
  fair game.

Please don't put private notes, photos or recordings in an issue.

## Your first code change

Issues labelled
[`good first issue`](https://github.com/Qharny/InkLeaf/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22)
are a good place to start. The *Known issues* in the
[latest release notes](release-notes/v1.0.0.md) are also open for anyone.

Leave a comment on the issue before you start, so two people don't build the
same thing.

### Set up

You need Flutter 3.47 (stable) with Dart 3.13 or newer, and the Android SDK.

```bash
git clone https://github.com/Qharny/InkLeaf.git
cd InkLeaf
flutter pub get
flutter run
```

The [README](README.md#project-structure) explains how the code is laid out.
Each feature in `lib/features/` keeps its data, models and screens together.

### Before you open a pull request

```bash
dart format .
flutter analyze
flutter test
```

GitHub Actions runs the same checks on every pull request.

- Keep each pull request to one change. Small ones get reviewed faster.
- Add or update a test when you change behaviour.
- If you change something on screen, add a before/after screenshot.
- Match the look: cream paper, charcoal ink, pencil outlines. Animations
  must be skipped when the phone's reduce-motion setting is on.
- Keep it local-first. Notes never leave the device, so no accounts,
  analytics or network calls for user data.

### Pull request steps

1. Fork the repo and create a branch from `main`, e.g. `fix/keyboard-toolbar`.
2. Commit with a short message that says what changed.
3. Open a pull request, link the issue (`Fixes #25`), and describe how you
   tested it.

## Be kind

Be patient and respectful in issues and reviews. Everyone here is
volunteering their time.

## License

By contributing, you agree that your work is released under the
[MIT License](LICENSE).
