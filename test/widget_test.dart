import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_note/app/app.dart';
import 'package:my_note/core/storage/app_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> startApp(
  WidgetTester tester, {
  bool onboardingDone = false,
}) async {
  SharedPreferences.setMockInitialValues({'onboarding_done': onboardingDone});
  await AppPrefs.init();
  await tester.pumpWidget(const InkleafApp());
  // Splash animation, its hold, then the fade to the next screen.
  await tester.pump(const Duration(seconds: 2));
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('first run: splash, onboarding pages, then home', (tester) async {
    await startApp(tester);

    expect(find.text('in ink'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    expect(find.text('again'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Inkleaf'), findsOneWidget);
    expect(AppPrefs.instance.onboardingDone, isTrue);
  });

  testWidgets('skip goes straight to home', (tester) async {
    await startApp(tester);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Inkleaf'), findsOneWidget);
    expect(AppPrefs.instance.onboardingDone, isTrue);
  });

  testWidgets('returning user skips onboarding; tabs switch', (tester) async {
    await startApp(tester, onboardingDone: true);

    expect(find.widgetWithText(AppBar, 'Inkleaf'), findsOneWidget);

    await tester.tap(find.text('Collections'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Collections'), findsOneWidget);
  });
}
