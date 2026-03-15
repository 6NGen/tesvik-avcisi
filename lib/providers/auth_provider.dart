// lib/providers/auth_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Mevcut kullanıcıyı dinleyen provider
final authProvider = StreamProvider<User?>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange
      .map((e) => e.session?.user);
});

// Auth state
class AuthState {
  final bool yukleniyor;
  final String? hata;

  const AuthState({
    this.yukleniyor = false,
    this.hata,
  });

  AuthState copyWith({bool? yukleniyor, String? hata}) => AuthState(
        yukleniyor: yukleniyor ?? this.yukleniyor,
        hata: hata,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  final _client = Supabase.instance.client;
  final _googleSignIn = GoogleSignIn();

  /// Google ile giriş yap
  Future<void> googleIleGirisYap() async {
    state = state.copyWith(yukleniyor: true, hata: null);
    try {
      // Google hesap seçici aç
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // Kullanıcı iptal etti
        state = state.copyWith(yukleniyor: false);
        return;
      }

      // Google token al
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        state = state.copyWith(
          yukleniyor: false,
          hata: 'Google girişi başarısız. Tekrar deneyin.',
        );
        return;
      }

      // Supabase'e giriş yap
      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      state = state.copyWith(yukleniyor: false);
    } catch (e) {
      state = state.copyWith(
        yukleniyor: false,
        hata: hataMesajiCevir(e.toString()),
      );
    }
  }

  /// Çıkış yap
  Future<void> cikisYap() async {
    await _googleSignIn.signOut();
    await _client.auth.signOut();
    state = const AuthState();
  }

  static String hataMesajiCevir(String hata) {
    if (hata.contains('network')) return 'İnternet bağlantısı yok.';
    if (hata.contains('cancelled')) return 'Giriş iptal edildi.';
    if (hata.contains('sign_in_failed')) return 'Google girişi başarısız.';
    return 'Bir hata oluştu. Tekrar deneyin.';
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);