import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design System — ARCANA TECH 2026
/// Light & Colorful Theme
class AppTheme {
  AppTheme._();

  // ─── Backgrounds (clair) ─────────────────────────────────
  static const Color bgDeep   = Color(0xFFEDF2FF); // bleu-lavande très clair
  static const Color bg       = Color(0xFFF5F7FF); // blanc bleuté
  static const Color bgAlt    = Color(0xFFEEF4FF); // variante
  static const Color bgCard   = Color(0xFFFFFFFF); // blanc pur

  // Backward compat aliases
  static const Color background     = bg;
  static const Color surface        = bgAlt;
  static const Color surfaceVariant = bgCard;

  // ─── Accent principal — Bleu vif ─────────────────────────
  static const Color cyan      = Color(0xFF2563EB); // bleu-600
  static const Color cyanLight = Color(0xFF60A5FA); // bleu-400
  static const Color cyanDark  = Color(0xFF1D4ED8); // bleu-700
  static const Color cyanSoft  = Color(0x152563EB); // bleu/8%

  // ─── Accent secondaire — Orange coral ────────────────────
  static const Color coral      = Color(0xFFF97316); // orange-500
  static const Color coralLight = Color(0xFFFB923C); // orange-400
  static const Color coralDark  = Color(0xFFEA580C); // orange-600
  static const Color coralSoft  = Color(0x15F97316);

  // ─── Accent tertiaire — Violet ───────────────────────────
  static const Color violet      = Color(0xFF7C3AED); // violet-600
  static const Color violetLight = Color(0xFFA78BFA); // violet-400
  static const Color violetDark  = Color(0xFF6D28D9); // violet-700
  static const Color violetSoft  = Color(0x157C3AED);

  // ─── Compat primaires ────────────────────────────────────
  static const Color primary      = cyan;
  static const Color primaryDark  = cyanDark;
  static const Color primaryLight = cyanLight;

  // ─── Accent alias ────────────────────────────────────────
  static const Color accent      = cyan;
  static const Color accentLight = cyanLight;
  static const Color accentSoft  = cyanSoft;

  // ─── Status (vraies couleurs) ────────────────────────────
  static const Color success      = Color(0xFF10B981); // emerald-500
  static const Color successLight = Color(0xFF34D399); // emerald-400
  static const Color warning      = Color(0xFFF59E0B); // amber-500
  static const Color warningLight = Color(0xFFFBBF24); // amber-400
  static const Color danger       = Color(0xFFEF4444); // red-500
  static const Color dangerLight  = Color(0x15EF4444);

  // ─── Textes (foncés sur fond clair) ──────────────────────
  static const Color textPrimary   = Color(0xFF111827); // gris-900
  static const Color textSecondary = Color(0xFF6B7280); // gris-500
  static const Color textTertiary  = Color(0xFF9CA3AF); // gris-400

  // ─── Bordures / verre ────────────────────────────────────
  static const Color cardBorder = Color(0x1A000000); // noir 10%
  static const Color divider    = Color(0x0F000000); // noir 6%
  static const Color glassEdge  = Color(0x22000000); // noir 13%

  // ─── Dégradé principal (Bleu → Violet) ───────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient primaryGradientH = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // ─── Dégradé secondaire (Orange → Corail) ────────────────
  static const LinearGradient coralGradient = LinearGradient(
    colors: [Color(0xFFF97316), Color(0xFFEA580C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Scanner / Header ────────────────────────────────────
  static const LinearGradient scannerGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF7C3AED), Color(0xFF6D28D9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient headerGradient = LinearGradient(
    colors: [bgDeep, bgCard],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ─── Fond léger ──────────────────────────────────────────
  static const LinearGradient obsidianGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bgDeep, bg, bgAlt],
    stops: [0.0, 0.5, 1.0],
  );

  // ─── Theme builder ───────────────────────────────────────
  static ThemeData buildTheme({
    Color primaryColor = cyan,
    Color secondaryColor = violet,
  }) {
    final colorScheme = ColorScheme.light(
      primary:     primaryColor,
      secondary:   secondaryColor,
      surface:     bgCard,
      onSurface:   textPrimary,
      error:       danger,
      onPrimary:   Colors.white,
      onSecondary: Colors.white,
      onError:     Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).apply(
        bodyColor:    textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: cardBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cyan, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: danger),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textTertiary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bgCard,
        selectedItemColor: cyan,
        unselectedItemColor: textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
      ),
      dividerColor: divider,
      chipTheme: ChipThemeData(
        backgroundColor: cyanSoft,
        labelStyle: const TextStyle(color: cyan),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  static Color hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}
