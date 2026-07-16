import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Wallify visual language.
///
/// The wallpapers are the product — the UI is a dark, quiet frame around
/// them. Ink canvas, glass surfaces, one iris accent, Space Grotesk for
/// display type and Inter for everything else.
abstract final class WallifyColors {
  static const ink = Color(0xFF0E0F13); // canvas
  static const surface = Color(0xFF161821); // cards, sheets
  static const surfaceHigh = Color(0xFF1F222E); // chips, inputs
  static const mist = Color(0xFFEDEEF2); // primary text
  static const smoke = Color(0xFF8A8D98); // secondary text
  static const iris = Color(0xFF8B95F6); // accent
  static const irisDeep = Color(0xFF5F6AE0);
}

ThemeData wallifyTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;

  final colorScheme = dark
      ? const ColorScheme.dark(
          primary: WallifyColors.iris,
          onPrimary: Color(0xFF10121C),
          secondary: WallifyColors.iris,
          onSecondary: Color(0xFF10121C),
          surface: WallifyColors.ink,
          onSurface: WallifyColors.mist,
          surfaceContainerHighest: WallifyColors.surfaceHigh,
          surfaceContainerHigh: WallifyColors.surfaceHigh,
          surfaceContainer: WallifyColors.surface,
          surfaceContainerLow: WallifyColors.surface,
          onSurfaceVariant: WallifyColors.smoke,
          outline: Color(0xFF31343F),
          outlineVariant: Color(0xFF23252E),
          inverseSurface: WallifyColors.mist,
          onInverseSurface: WallifyColors.ink,
        )
      : ColorScheme.fromSeed(
          seedColor: WallifyColors.irisDeep,
          brightness: Brightness.light,
        );

  final baseText = GoogleFonts.interTextTheme(
    dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
  );

  final display = GoogleFonts.spaceGrotesk(
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: colorScheme.onSurface,
  );

  final textTheme = baseText.copyWith(
    displayLarge: display.copyWith(fontSize: 40),
    displayMedium: display.copyWith(fontSize: 32),
    headlineLarge: display.copyWith(fontSize: 28),
    headlineMedium: display.copyWith(fontSize: 24),
    titleLarge: display.copyWith(fontSize: 20, letterSpacing: -0.3),
    labelLarge: GoogleFonts.spaceGrotesk(
      fontWeight: FontWeight.w500,
      letterSpacing: 0.2,
    ),
  );

  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    textTheme: textTheme,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: textTheme.headlineMedium,
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide(color: colorScheme.outlineVariant),
      backgroundColor: Colors.transparent,
      selectedColor: colorScheme.onSurface,
      showCheckmark: false,
      labelStyle: GoogleFonts.spaceGrotesk(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurfaceVariant,
      ),
      secondaryLabelStyle: GoogleFonts.spaceGrotesk(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: colorScheme.surface,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.spaceGrotesk(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? WallifyColors.surfaceHigh : null,
      contentTextStyle: baseText.bodyMedium?.copyWith(
        color: dark ? WallifyColors.mist : null,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? WallifyColors.surface : null,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? WallifyColors.surface : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}
