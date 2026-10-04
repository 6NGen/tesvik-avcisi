// lib/core/theme/app_theme.dart
//
// Tasarım sistemi: marka renkleri (orman yeşili + buğday altını), açık/koyu
// ColorScheme ve durum renkleri (AppRenkler ThemeExtension). Ekranlar sabit
// renk yerine Theme.of(context).colorScheme ve context.renkler kullanır.

import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ── MARKA RENKLERİ ───────────────────────────────────────────
  static const ormanYesili = Color(0xFF1B5E20);
  static const ortaYesil = Color(0xFF2E7D32);
  static const acikYesil = Color(0xFF4CAF50);
  static const bugdayAltini = Color(0xFFF9A825);
  static const toprakKahve = Color(0xFF5D4037);

  static const _radius = 16.0;

  static ThemeData get light => _tema(
        ColorScheme.fromSeed(
          seedColor: ormanYesili,
          primary: ormanYesili,
          secondary: bugdayAltini,
          onSecondary: const Color(0xFF1A1A1A),
          surface: const Color(0xFFFAFBF7),
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: const Color(0xFFF3F6EE),
          surfaceContainer: const Color(0xFFEDF2E7),
          error: const Color(0xFFC62828),
        ),
        AppRenkler.acik,
      );

  static ThemeData get dark => _tema(
        ColorScheme.fromSeed(
          seedColor: ormanYesili,
          brightness: Brightness.dark,
          primary: const Color(0xFF8BD68F),
          secondary: bugdayAltini,
          onSecondary: const Color(0xFF1A1A1A),
        ),
        AppRenkler.koyu,
      );

  static ThemeData _tema(ColorScheme cs, AppRenkler renkler) {
    final koyu = cs.brightness == Brightness.dark;
    final baslikArka = koyu ? cs.surfaceContainer : ormanYesili;
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: cs.surface,
      extensions: [renkler],
      appBarTheme: AppBarTheme(
        backgroundColor: baslikArka,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cs.surfaceContainerLowest,
        indicatorColor: cs.primaryContainer,
        elevation: 3,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 12,
            fontWeight:
                s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: BorderSide(color: cs.outlineVariant),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: cs.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: cs.outlineVariant),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant.withValues(alpha: 0.5),
        space: 1,
      ),
    );
  }
}

/// Durum renkleri (başarı / uyarı / tehlike / bilgi). Her biri ön plan + zemin.
@immutable
class AppRenkler extends ThemeExtension<AppRenkler> {
  final Color basari, basariZemin;
  final Color uyari, uyariZemin;
  final Color tehlike, tehlikeZemin;
  final Color bilgi, bilgiZemin;
  final Color notr, notrZemin;
  final Color baslikGradyanBas, baslikGradyanSon;

  const AppRenkler({
    required this.basari,
    required this.basariZemin,
    required this.uyari,
    required this.uyariZemin,
    required this.tehlike,
    required this.tehlikeZemin,
    required this.bilgi,
    required this.bilgiZemin,
    required this.notr,
    required this.notrZemin,
    required this.baslikGradyanBas,
    required this.baslikGradyanSon,
  });

  static const acik = AppRenkler(
    basari: Color(0xFF1B5E20),
    basariZemin: Color(0xFFE8F5E9),
    uyari: Color(0xFFB26A00),
    uyariZemin: Color(0xFFFFF4DC),
    tehlike: Color(0xFFC62828),
    tehlikeZemin: Color(0xFFFDECEA),
    bilgi: Color(0xFF1565C0),
    bilgiZemin: Color(0xFFE6F0FB),
    notr: Color(0xFF616161),
    notrZemin: Color(0xFFF1F1F1),
    baslikGradyanBas: AppTheme.ormanYesili,
    baslikGradyanSon: AppTheme.ortaYesil,
  );

  static const koyu = AppRenkler(
    basari: Color(0xFF8BD68F),
    basariZemin: Color(0xFF1E3A20),
    uyari: Color(0xFFFFC857),
    uyariZemin: Color(0xFF3D3016),
    tehlike: Color(0xFFFF8A80),
    tehlikeZemin: Color(0xFF442222),
    bilgi: Color(0xFF90CAF9),
    bilgiZemin: Color(0xFF1C2D44),
    notr: Color(0xFFBDBDBD),
    notrZemin: Color(0xFF2C2C2C),
    baslikGradyanBas: Color(0xFF123F16),
    baslikGradyanSon: Color(0xFF1B5E20),
  );

  @override
  AppRenkler copyWith() => this;

  @override
  AppRenkler lerp(ThemeExtension<AppRenkler>? other, double t) {
    if (other is! AppRenkler) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppRenkler(
      basari: l(basari, other.basari),
      basariZemin: l(basariZemin, other.basariZemin),
      uyari: l(uyari, other.uyari),
      uyariZemin: l(uyariZemin, other.uyariZemin),
      tehlike: l(tehlike, other.tehlike),
      tehlikeZemin: l(tehlikeZemin, other.tehlikeZemin),
      bilgi: l(bilgi, other.bilgi),
      bilgiZemin: l(bilgiZemin, other.bilgiZemin),
      notr: l(notr, other.notr),
      notrZemin: l(notrZemin, other.notrZemin),
      baslikGradyanBas: l(baslikGradyanBas, other.baslikGradyanBas),
      baslikGradyanSon: l(baslikGradyanSon, other.baslikGradyanSon),
    );
  }
}

extension TemaKisayollari on BuildContext {
  AppRenkler get renkler =>
      Theme.of(this).extension<AppRenkler>() ?? AppRenkler.acik;
  ColorScheme get cs => Theme.of(this).colorScheme;
  TextTheme get tt => Theme.of(this).textTheme;
}
