import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'sketch_styles.dart';

/// Material theme for Inkleaf.
///
/// Sketchbook look from the design blueprint: hand-lettered type throughout
/// (Kalam for headings, the clearer Patrick Hand for body and labels), double
/// pencil outlines, ink-black primary actions and pastel paper surfaces.
abstract final class AppTheme {
  static ThemeData get light => _build(
    brightness: Brightness.light,
    scheme: const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.sageDeep,
      onPrimary: AppColors.paperLight,
      primaryContainer: AppColors.sageLight,
      onPrimaryContainer: AppColors.ink,
      secondary: AppColors.pencil,
      onSecondary: AppColors.ink,
      secondaryContainer: AppColors.pencilLight,
      onSecondaryContainer: AppColors.ink,
      tertiary: AppColors.sage,
      onTertiary: AppColors.ink,
      error: AppColors.error,
      onError: AppColors.paperLight,
      errorContainer: AppColors.errorLight,
      onErrorContainer: AppColors.ink,
      surface: AppColors.paper,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.inkSoft,
      surfaceContainerLowest: AppColors.paperLight,
      surfaceContainerLow: AppColors.paperLight,
      surfaceContainer: AppColors.paper,
      surfaceContainerHigh: AppColors.paperDark,
      surfaceContainerHighest: AppColors.paperDark,
      outline: AppColors.ink,
      outlineVariant: AppColors.ruledLine,
      inverseSurface: AppColors.ink,
      onInverseSurface: AppColors.paper,
      inversePrimary: AppColors.sageLight,
      shadow: AppColors.ink,
      scrim: AppColors.ink,
    ),
  );

  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    scheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.nightSage,
      onPrimary: AppColors.nightPaper,
      primaryContainer: AppColors.sageDeep,
      onPrimaryContainer: AppColors.nightInk,
      secondary: AppColors.pencil,
      onSecondary: AppColors.ink,
      secondaryContainer: AppColors.pencilDeep,
      onSecondaryContainer: AppColors.nightInk,
      tertiary: AppColors.sage,
      onTertiary: AppColors.nightPaper,
      error: Color(0xFFF0A08F),
      onError: AppColors.nightPaper,
      errorContainer: Color(0xFF6E2A1F),
      onErrorContainer: AppColors.nightInk,
      surface: AppColors.nightPaper,
      onSurface: AppColors.nightInk,
      onSurfaceVariant: AppColors.nightInkSoft,
      surfaceContainerLowest: AppColors.nightPaper,
      surfaceContainerLow: AppColors.nightSurface,
      surfaceContainer: AppColors.nightSurface,
      surfaceContainerHigh: AppColors.nightSurfaceHigh,
      surfaceContainerHighest: AppColors.nightSurfaceHigh,
      outline: AppColors.nightInkSoft,
      outlineVariant: AppColors.nightLine,
      inverseSurface: AppColors.paper,
      onInverseSurface: AppColors.ink,
      inversePrimary: AppColors.sageDeep,
      shadow: Colors.black,
      scrim: Colors.black,
    ),
  );

  static TextTheme _textTheme(ColorScheme scheme) {
    final base = Typography.material2021(platform: defaultTargetPlatform)
        .englishLike;
    // Patrick Hand runs small, so body sizes are bumped ~10%.
    TextStyle? script(TextStyle? s) => GoogleFonts.patrickHand(
      textStyle: s?.copyWith(fontSize: (s.fontSize ?? 14) * 1.1),
    );
    final body = TextTheme(
      displayLarge: script(base.displayLarge),
      displayMedium: script(base.displayMedium),
      displaySmall: script(base.displaySmall),
      headlineLarge: script(base.headlineLarge),
      headlineMedium: script(base.headlineMedium),
      headlineSmall: script(base.headlineSmall),
      titleLarge: script(base.titleLarge),
      titleMedium: script(base.titleMedium),
      titleSmall: script(base.titleSmall),
      bodyLarge: script(base.bodyLarge),
      bodyMedium: script(base.bodyMedium),
      bodySmall: script(base.bodySmall),
      labelLarge: script(base.labelLarge),
      labelMedium: script(base.labelMedium),
      labelSmall: script(base.labelSmall),
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
    TextStyle hand(TextStyle? base, double size) =>
        GoogleFonts.kalam(textStyle: base)
            .copyWith(fontSize: size, fontWeight: FontWeight.w700, height: 1.2);

    return body.copyWith(
      displayLarge: hand(body.displayLarge, 52),
      displayMedium: hand(body.displayMedium, 42),
      displaySmall: hand(body.displaySmall, 34),
      headlineLarge: hand(body.headlineLarge, 30),
      headlineMedium: hand(body.headlineMedium, 27),
      headlineSmall: hand(body.headlineSmall, 24),
      titleLarge: hand(body.titleLarge, 21),
    );
  }

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
  }) {
    final text = _textTheme(scheme);
    final ink = scheme.outline;
    final sketch = SketchBorder(
      side: BorderSide(color: ink, width: SketchStyles.strokeWidth),
    );
    final sketchSmall = SketchBorder(
      side: BorderSide(color: ink, width: SketchStyles.strokeWidth),
      radius: SketchStyles.radiusSmall,
      seed: 3,
    );
    OutlineInputBorder inputBorder(Color color, [double width = 1.4]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(SketchStyles.radiusSmall),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.headlineSmall,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.all(6),
        shape: sketch,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1.2,
        space: 24,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.markerYellow,
        indicatorShape: sketchSmall,
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.ink
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        // Ink-black round + button, as in the blueprint.
        backgroundColor: scheme.inverseSurface,
        foregroundColor: scheme.onInverseSurface,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: SketchBorder(
          side: BorderSide(color: scheme.inverseSurface, width: 2),
          radius: 40,
          seed: 11,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // Ink pill ("Get Started").
          backgroundColor: scheme.inverseSurface,
          foregroundColor: scheme.onInverseSurface,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 28),
          shape: SketchBorder(
            side: BorderSide(color: scheme.inverseSurface, width: 2),
            radius: 26,
            seed: 13,
          ),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          // Outlined pill ("Log in"), the partner of the ink pill.
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 28),
          shape: const SketchBorder(radius: 26, seed: 17),
          side: BorderSide(color: ink, width: SketchStyles.strokeWidth),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(48, 48),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(48, 48),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        border: inputBorder(ink),
        enabledBorder: inputBorder(ink),
        focusedBorder: inputBorder(scheme.primary, 2.2),
        errorBorder: inputBorder(scheme.error),
        focusedErrorBorder: inputBorder(scheme.error, 2.2),
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerLowest),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(sketch),
        constraints: const BoxConstraints(minHeight: 52),
        textStyle: WidgetStatePropertyAll(text.bodyLarge),
        hintStyle: WidgetStatePropertyAll(
          text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        selectedColor: scheme.secondaryContainer,
        side: BorderSide(color: ink, width: 1.2),
        shape: sketchSmall,
        labelStyle: text.labelLarge,
      ),
      checkboxTheme: CheckboxThemeData(
        side: BorderSide(color: ink, width: 1.6),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(scheme.onPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: sketch,
        titleTextStyle: text.headlineSmall,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: sketchSmall,
        textStyle: text.bodyLarge,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: sketchSmall.copyWith(
          side: BorderSide(color: scheme.inverseSurface),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurface,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        minVerticalPadding: 12,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: AppColors.pencil.withValues(alpha: 0.55),
        selectionHandleColor: scheme.primary,
      ),
    );
  }
}
