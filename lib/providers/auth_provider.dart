// lib/providers/auth_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

// Mevcut kullanıcıyı dinleyen provider
// null → giriş yapılmamış, User → giriş yapılmış
final authProvider = StreamProvider<User?>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange.map((e) => e.session?.user);
});

// Auth işlemleri için notifier
class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  AuthNotifier() : super(const AsyncValue.data(null));

  final _client = Supabase.instance.client;

  // Kayıt ol
  Future<void> kayitOl({
    required String email,
    required String sifre,
    required String adSoyad,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _client.auth.signUp(
        email: email,
        password: sifre,
        data: {'ad_soyad': adSoyad},
      );
      state = const AsyncValue.data(null);
    } catch (e) {debugPrint('KAYIT HATASI: $e');
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  // Giriş yap
  Future<void> girisYap({
    required String email,
    required String sifre,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: sifre,
      );
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  // Çıkış yap
  Future<void> cikisYap() async {
    await _client.auth.signOut();
  }

  // Hata mesajını Türkçe'ye çevir
  static String hataMesajiCevir(String hata) {
    if (hata.contains('Invalid login credentials')) {
      return 'E-posta veya şifre hatalı.';
    } else if (hata.contains('Email already registered') ||
        hata.contains('User already registered')) {
      return 'Bu e-posta zaten kayıtlı.';
    } else if (hata.contains('Password should be at least')) {
      return 'Şifre en az 6 karakter olmalı.';
    } else if (hata.contains('Unable to validate email')) {
      return 'Geçersiz e-posta adresi.';
    } else if (hata.contains('network')) {
      return 'İnternet bağlantısı yok.';
    }
    return 'Bir hata oluştu. Tekrar deneyin.';
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>(
  (ref) => AuthNotifier(),
);