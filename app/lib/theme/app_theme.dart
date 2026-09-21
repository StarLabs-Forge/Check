import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens de CHECK, extraídos directamente del archivo de Figma
/// ("🖥️ Dashboard Web" / Foundations) vía las variables del documento.
/// No inventar valores nuevos acá — si falta un token, se pide al diseño.
class AppColors {
  AppColors._();

  static const Color bgPrimary = Color(0xFF0A0A0A);
  static const Color bgSurface = Color(0xFF141414);
  static const Color bgInput = Color(0xFF1A1A1A);
  static const Color bgBorder = Color(0xFF2A2A2A);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF888888);

  static const Color accentPrimary = Color(0xFF00FF88);
  static const Color accentSubtle = Color(0xFF0D2B1A);

  static const Color success = Color(0xFF00C853);
  static const Color error = Color(0xFFFF3B3B);

  // Tokens agregados al construir Eventos / Tickets (Figma Foundations):
  // usados por los Badge de estado "Borrador" y "Cerrado/Cancelado".
  static const Color textDisabled = Color(0xFF444444);
  static const Color bgDraft = Color(0xFF1E1E1E);
  static const Color bgDanger = Color(0xFF2B0D0D);
}

class AppRadius {
  AppRadius._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double input = 10;
  static const double metric = 14;
  static const double full = 9999;
  static const double modal = 20;
}

class AppSpacing {
  AppSpacing._();

  static const double s0 = 0;
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;
}

class AppTextSize {
  AppTextSize._();

  static const double caption = 12;
  static const double body = 14;
  static const double bodyLg = 16;
  static const double h3 = 18;
  static const double h2 = 24;
  static const double h1 = 32;
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bgPrimary,
      textTheme: textTheme,
      colorScheme: base.colorScheme.copyWith(
        surface: AppColors.bgPrimary,
        primary: AppColors.accentPrimary,
        secondary: AppColors.accentPrimary,
        error: AppColors.error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgInput,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s3,
        ),
        hintStyle: GoogleFonts.inter(
          color: AppColors.textSecondary,
          fontSize: AppTextSize.body,
        ),
        labelStyle: GoogleFonts.inter(
          color: AppColors.textSecondary,
          fontSize: AppTextSize.body,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.bgBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.bgBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.accentPrimary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.error, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentPrimary,
          foregroundColor: AppColors.bgPrimary,
          disabledBackgroundColor: AppColors.bgBorder,
          disabledForegroundColor: AppColors.textSecondary,
          minimumSize: const Size.fromHeight(44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: AppTextSize.body,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accentPrimary,
          minimumSize: const Size.fromHeight(44),
          side: const BorderSide(color: AppColors.accentPrimary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: AppTextSize.body,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          textStyle: GoogleFonts.inter(
            fontSize: AppTextSize.body,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.bgBorder),
    );
  }
}
