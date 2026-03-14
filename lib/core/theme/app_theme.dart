// lib/core/theme/app_theme.dart

import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ── RENKLER ──────────────────────────────────────────────────
  static const ormanYesili   = Color(0xFF1B5E20); // ana renk
  static const ortaYesil     = Color(0xFF2E7D32);
  static const acikYesil     = Color(0xFF4CAF50);
  static const cimensoluk    = Color(0xFFF1F8E9); // arka plan
  static const yaprakAcik    = Color(0xFFE8F5E9);
  static const bugdayAltini  = Color(0xFFF9A825); // aksan
  static const altinAcik     = Color(0xFFFFF8E1);
  static const toprakKahve   = Color(0xFF5D4037);
  static const kremBeyaz     = Color(0xFFFAFAF7);
  static const koyu          = Color(0xFF1A1A1A);
  static const gri           = Color(0xFF757575);
  static const griAcik       = Color(0xFFEEEEEE);
  static const hata          = Color(0xFFC62828);

  // ── TEMA ─────────────────────────────────────────────────────
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: ormanYesili,
          primary: ormanYesili,
          secondary: bugdayAltini,
          surface: kremBeyaz,
          background: cimensoluk,
        ),
        scaffoldBackgroundColor: cimensoluk,
        appBarTheme: const AppBarTheme(
          backgroundColor: ormanYesili,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: ormanYesili,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            elevation: 2,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: kremBeyaz,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.green.shade100, width: 1),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: ormanYesili, width: 2),
          ),
          labelStyle: const TextStyle(color: gri),
        ),
      );
}