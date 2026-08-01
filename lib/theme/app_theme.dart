import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Bible Xpress — near-black + hot pink (Opek-inspired dark system).
class Bx {
  // Brand pink
  static const grove = Color(0xFFFF006E); // primary accent
  static const groveDeep = Color(0xFFE60063);
  static const brass = Color(0xFFFF3387); // soft pink accent
  static const brandSoft = Color(0xFFFFD6E6);
  static const glow = Color(0x59FF006E);

  // Surfaces
  static const mist = Color(0xFF070709); // scaffold / bg
  static const bgAlt = Color(0xFF0B0B0F);
  static const paper = Color(0xFF101014); // cards / sheets
  static const mistDeep = Color(0xFF16161C); // elevated
  static const card = Color(0xFF121218);
  static const input = Color(0xFF0E0E12);

  // Text
  static const ink = Color(0xFFF4F4F5);
  static const muted = Color(0xFFA1A1AA);
  static const placeholder = Color(0xFF63636B);

  // Chrome
  static const border = Color(0x14FFFFFF);
  static const borderStrong = Color(0x1FFFFFFF);
  static const borderHover = Color(0x38FFFFFF);

  // Status
  static const danger = Color(0xFFEF4444);
  static const success = Color(0xFF10B981);
}

class AppTheme {
  static TextTheme _textTheme() {
    final sans = GoogleFonts.plusJakartaSans(
      color: Bx.ink,
      height: 1.35,
      letterSpacing: -0.2,
    );
    final display = GoogleFonts.instrumentSerif(
      color: Bx.ink,
      fontWeight: FontWeight.w400,
      height: 1.12,
      letterSpacing: -0.4,
    );

    return TextTheme(
      displayLarge: display.copyWith(fontSize: 44),
      displayMedium: display.copyWith(fontSize: 36),
      displaySmall: display.copyWith(fontSize: 28),
      headlineLarge: display.copyWith(fontSize: 28),
      headlineMedium: sans.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: Colors.white,
      ),
      headlineSmall: sans.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleLarge: sans.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
      titleMedium: sans.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall: sans.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      bodyLarge: sans.copyWith(fontSize: 17, height: 1.55),
      bodyMedium: sans.copyWith(fontSize: 15, height: 1.5),
      bodySmall: sans.copyWith(fontSize: 13, color: Bx.muted, height: 1.45),
      labelLarge: sans.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
      labelMedium: sans.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Bx.muted,
      ),
      labelSmall: sans.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Bx.muted,
        letterSpacing: 1.4,
      ),
    );
  }

  static ThemeData get dark {
    final text = _textTheme();
    final scheme = const ColorScheme.dark(
      primary: Bx.grove,
      onPrimary: Colors.white,
      primaryContainer: Bx.groveDeep,
      onPrimaryContainer: Bx.brandSoft,
      secondary: Bx.brass,
      onSecondary: Colors.white,
      surface: Bx.paper,
      onSurface: Bx.ink,
      onSurfaceVariant: Bx.muted,
      surfaceContainerHighest: Bx.mistDeep,
      surfaceContainerHigh: Bx.card,
      outline: Bx.borderStrong,
      error: Bx.danger,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: Bx.mist,
      textTheme: text,
      primaryTextTheme: text,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: const Color(0xD908080B),
        foregroundColor: Bx.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: Bx.ink,
          fontWeight: FontWeight.w700,
          fontSize: 18,
          letterSpacing: -0.3,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Bx.border,
        thickness: 1,
        space: 1,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: Bx.grove,
        unselectedLabelColor: Bx.muted,
        indicatorColor: Bx.grove,
        labelStyle: text.labelLarge,
        unselectedLabelStyle:
            text.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        dividerColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Bx.input,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Bx.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Bx.grove, width: 1.5),
        ),
        hintStyle: text.bodyMedium?.copyWith(color: Bx.placeholder),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Bx.grove,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Bx.grove.withValues(alpha: 0.35),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0x1AFFFFFF), width: 2),
          ),
          elevation: 0,
          shadowColor: Bx.grove,
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Bx.grove,
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Bx.ink,
          side: const BorderSide(color: Color(0x26FFFFFF)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Bx.mistDeep,
        contentTextStyle: text.bodyMedium?.copyWith(color: Bx.ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Bx.paper,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: Bx.borderHover,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Bx.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: text.headlineSmall,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: Bx.grove,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodySmall,
      ),
      iconTheme: const IconThemeData(color: Bx.ink),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Bx.grove,
        circularTrackColor: Bx.mistDeep,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Bx.grove,
        foregroundColor: Colors.white,
      ),
    );
  }

  /// Full dark product — light alias keeps MaterialApp wiring simple.
  static ThemeData get light => dark;
}
