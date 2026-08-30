import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'kalonet_colors.dart';
import 'kalonet_tokens.dart';

abstract final class KalonetTheme {
  static ThemeData dark() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: KalonetColors.primary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: KalonetColors.primary,
          onPrimary: KalonetColors.background,
          primaryContainer: KalonetColors.surfaceElevated,
          onPrimaryContainer: KalonetColors.primaryBright,
          secondary: KalonetColors.primaryBright,
          onSecondary: KalonetColors.background,
          surface: KalonetColors.surface,
          onSurface: KalonetColors.textPrimary,
          surfaceContainerLowest: KalonetColors.background,
          surfaceContainerLow: KalonetColors.surfaceSunken,
          surfaceContainer: KalonetColors.surface,
          surfaceContainerHigh: KalonetColors.surfaceElevated,
          surfaceContainerHighest: KalonetColors.surfaceElevated,
          outline: KalonetColors.border,
          error: KalonetColors.error,
          onError: KalonetColors.background,
        );

    final body = GoogleFonts.spaceGrotesk(
      color: KalonetColors.textPrimary,
      height: 1.35,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: KalonetColors.background,
      canvasColor: KalonetColors.background,
      fontFamily: 'Space Grotesk',
      textTheme: TextTheme(
        displaySmall: body.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
        ),
        headlineMedium: body.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineSmall: body.copyWith(fontSize: 24, fontWeight: FontWeight.w700),
        titleLarge: body.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
        titleMedium: body.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
        bodyLarge: body.copyWith(fontSize: 16),
        bodyMedium: body.copyWith(
          fontSize: 14,
          color: KalonetColors.textSecondary,
        ),
        bodySmall: body.copyWith(fontSize: 12, color: KalonetColors.textMuted),
        labelLarge: body.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
        labelMedium: body.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: KalonetColors.textSecondary,
        ),
        labelSmall: body.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: KalonetColors.textMuted,
        ),
      ),
      extensions: const [KalonetThemeTokens.dark()],
      appBarTheme: const AppBarTheme(
        backgroundColor: KalonetColors.surfaceGlass,
        foregroundColor: KalonetColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        shape: Border(bottom: BorderSide(color: KalonetColors.borderPale)),
        titleTextStyle: TextStyle(
          fontFamily: 'Space Grotesk',
          color: KalonetColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: KalonetColors.surfaceGlass,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: KalonetSpacing.md,
          vertical: 18,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        floatingLabelStyle: const TextStyle(
          color: KalonetColors.primaryBright,
          fontWeight: FontWeight.w700,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KalonetRadii.md),
          borderSide: const BorderSide(color: KalonetColors.borderPale),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KalonetRadii.md),
          borderSide: const BorderSide(color: KalonetColors.borderPale),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KalonetRadii.md),
          borderSide: const BorderSide(
            color: KalonetColors.primary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KalonetRadii.md),
          borderSide: const BorderSide(color: KalonetColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KalonetRadii.md),
          borderSide: const BorderSide(color: KalonetColors.error, width: 1.5),
        ),
        hintStyle: const TextStyle(color: KalonetColors.textSecondary),
        labelStyle: const TextStyle(color: KalonetColors.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: KalonetColors.primary,
          foregroundColor: KalonetColors.background,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KalonetRadii.md),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: KalonetColors.primary,
          foregroundColor: KalonetColors.background,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KalonetRadii.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: KalonetColors.textPrimary,
          side: const BorderSide(color: KalonetColors.border),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KalonetRadii.md),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: KalonetColors.surfaceGlass,
        margin: EdgeInsets.zero,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KalonetRadii.lg),
          side: const BorderSide(color: KalonetColors.borderPale),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: KalonetColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: KalonetElevation.dialog,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KalonetRadii.lg),
          side: const BorderSide(color: KalonetColors.border),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: KalonetColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        modalBarrierColor: KalonetColors.scrim,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: KalonetColors.surfaceElevated,
        contentTextStyle: body.copyWith(fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KalonetRadii.sm),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: KalonetColors.surfaceGlass,
        indicatorColor: KalonetColors.primary.withValues(alpha: 0.2),
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          body.copyWith(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        height: 72,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: KalonetColors.primary,
        linearTrackColor: KalonetColors.border,
        circularTrackColor: KalonetColors.border,
      ),
      dividerTheme: const DividerThemeData(color: KalonetColors.border),
    );
  }
}
