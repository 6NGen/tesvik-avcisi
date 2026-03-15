// lib/providers/auth_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profil_provider.dart';

final authProvider = StreamProvider<User?>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange
      .map((e) => e.session?.user);
});

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
  final Ref _ref;

  AuthNotifier(this._ref) : super(const AuthState());

  final _client = Supabase.instance.client;
  final _googleSignIn = GoogleSignIn();

  Future<void> googleIleGirisYap() async {
    state = state.copyWith(yukleniyor: true, hata: null);
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        state = state.copyWith(yukleniyor: false);
        return;
      }

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

      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      // Giriş yapılınca profili yeniden yükle
      await _ref.read(profilProvider.notifier).yenile();

      state = state.copyWith(yukleniyor: false);
    } catch (e) {
      state = state.copyWith(
        yukleniyor: false,
        hata: hataMesajiCevir(e.toString()),
      );
    }
  }

  Future<void> cikisYap() async {
    state = state.copyWith(yukleniyor: true);
    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
      await _client.auth.signOut();
      // Çıkış yapınca profili sıfırla
      _ref.read(profilProvider.notifier).sifirla();
    } catch (e) {
      // Hata olsa bile devam et
    } finally {
      state = const AuthState();
    }
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
  (ref) => AuthNotifier(ref),
);