import 'package:flutter/foundation.dart';

/// A note to open as soon as the home screen is showing: one made from a
/// share, or one whose reminder notification was tapped.
///
/// Going through home means a note that launched the app waits for the
/// splash (and onboarding) to finish first. Home opens it and clears this.
final pendingNoteToOpen = ValueNotifier<String?>(null);

/// A screen to open the same way, by its route location: a new note,
/// recording or scan started from the home-screen widget.
final pendingLocationToOpen = ValueNotifier<String?>(null);
