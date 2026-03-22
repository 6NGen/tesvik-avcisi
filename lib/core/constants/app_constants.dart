// lib/core/constants/app_constants.dart

import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  AppConstants._();

  static const supabaseUrl = 'https://iolnaxaudgzatyrwhpaw.supabase.co';
  static const supabaseKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlvbG5heGF1ZGd6YXR5cndocGF3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMzNzQzNTUsImV4cCI6MjA4ODk1MDM1NX0.0s-kpKIjPxO52iaqib1Z-kqMNd4WWopwV_1K0WUj0Cw';
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static const geminiModel = 'gemini-2.5-flash';
  static const fcmVapidKey =
      'BCbuDpNcLLn6GDhwDjBqSFg0oHqXIAPQvqvLDOPo7ZS8Dz3uZ3vUcscXw7VkJkIi9qTvz_j9_PlP6YlsJ64XSpg';
  static String get admobBannerId => dotenv.env['ADMOB_BANNER_ID'] ?? '';
  static String get admobRewardedId => dotenv.env['ADMOB_REWARDED_ID'] ?? '';
  }