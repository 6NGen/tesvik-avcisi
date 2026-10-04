// lib/providers/auth_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notification_service.dart';
import 'profil_provider.dart';

/// Oturumdaki kullanıcı (null = misafir). Supabase ilk olarak mevcut oturumu
/// (initialSession) yayınlar.
final authProvider = StreamProvider<User?>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange
      .map((e) => e.session?.user);
});

/// Yalnızca kullanıcı DEĞİŞTİĞİNDE yeniden hesaplanan id. Token yenileme
/// olayları buna bağlı provider'ları gereksiz yere yeniden kurmaz.
final kullaniciIdProvider = Provider<String?>(
  (ref) => ref.watch(authProvider.select((a) => a.valueOrNull?.id)),
);

class AuthState {
  final bool yukleniyor;
  final String? hata;

  const AuthState({this.yukleniyor = false, this.hata});
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  AuthNotifier(this._ref) : super(const AuthState());

  final _client = Supabase.instance.client;
  final _googleSignIn = GoogleSignIn();

  /// Başarılıysa true.
  Future<bool> googleIleGirisYap() async {
    if (state.yukleniyor) return false;
    state = const AuthState(yukleniyor: true);
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        state = const AuthState(); // kullanıcı vazgeçti — hata değil
        return false;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        state = const AuthState(hata: 'Google girişi başarısız. Tekrar dene.');
        return false;
      }

      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );

      // Profili beklemeden yükle (yönlendirme profil durumuna göre yapılır)
      await _ref.read(profilProvider.notifier).yenile();
      // FCM token'ını bu kullanıcıya bağla (push kişiselleştirmesi için)
      await NotificationService().tokeniKullaniciylaEslestir();

      state = const AuthState();
      return true;
    } catch (e) {
      state = AuthState(hata: hataMesajiCevir(e.toString()));
      return false;
    }
  }

  Future<void> cikisYap() async {
    state = const AuthState(yukleniyor: true);
    try {
      if (await _googleSignIn.isSignedIn()) await _googleSignIn.signOut();
    } catch (_) {/* Google oturumu kapanamasa da Supabase çıkışı yapılmalı */}
    try {
      await _client.auth.signOut();
    } catch (_) {/* ağ yoksa bile yerel oturum temizlenir */}
    _ref.read(profilProvider.notifier).sifirla();
    // Token'ın user_id'sini null'a çek (cihaz misafire döner)
    await NotificationService().tokeniKullaniciylaEslestir();
    state = const AuthState();
  }

  static String hataMesajiCevir(String hata) {
    final h = hata.toLowerCase();
    if (h.contains('network') || h.contains('socket')) {
      return 'İnternet bağlantısı yok.';
    }
    if (h.contains('cancel')) return 'Giriş iptal edildi.';
    if (h.contains('apiexception: 10') || h.contains('developer_error')) {
      return 'Google giriş yapılandırması hatalı (SHA-1). Geliştiriciye bildir.';
    }
    if (h.contains('sign_in_failed')) return 'Google girişi başarısız.';
    return 'Bir hata oluştu. Tekrar dene.';
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref),
);
