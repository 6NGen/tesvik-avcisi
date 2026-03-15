// lib/providers/profil_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profil_model.dart';

// Profil yükleme durumu
enum ProfilYukleme { yukleniyor, var_, yok }

class ProfilState {
  final ProfilYukleme durum;
  final ProfilModel? profil;

  const ProfilState({
    required this.durum,
    this.profil,
  });

  // Yükleniyor mu?
  bool get yukleniyor => durum == ProfilYukleme.yukleniyor;

  // Profil var mı?
  bool get profilVar => durum == ProfilYukleme.var_;

  // Profil yok mu? (yükleme bitti, gerçekten yok)
  bool get profilYok => durum == ProfilYukleme.yok;
}

class ProfilNotifier extends StateNotifier<ProfilState> {
  ProfilNotifier()
      : super(const ProfilState(durum: ProfilYukleme.yukleniyor)) {
    _profilYukle();
  }

  final _client = Supabase.instance.client;

  Future<void> _profilYukle() async {
    final user = _client.auth.currentUser;

    // Kullanıcı giriş yapmamış → profil yok (yükleme gerekmiyor)
    if (user == null) {
      state = const ProfilState(durum: ProfilYukleme.yok);
      return;
    }

    try {
      final response = await _client
          .from('kullanici_profilleri')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null) {
        // Kullanıcı var ama profil yok → profil ekranı göster
        state = const ProfilState(durum: ProfilYukleme.yok);
      } else {
        // Profil bulundu
        state = ProfilState(
          durum: ProfilYukleme.var_,
          profil: ProfilModel.fromJson(
              response as Map<String, dynamic>),
        );
      }
    } catch (e) {
      // Hata olursa profil yok say (tekrar sormaktan iyisi)
      state = const ProfilState(durum: ProfilYukleme.yok);
    }
  }

  // Profili kaydet
  Future<bool> profilKaydet(ProfilModel profil) async {
    try {
      await _client.from('kullanici_profilleri').upsert(
        profil.toJson(),
        onConflict: 'user_id',
      );
      state = ProfilState(
        durum: ProfilYukleme.var_,
        profil: profil,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // Profili yeniden yükle (giriş yapınca çağrılır)
  Future<void> yenile() => _profilYukle();

  // Çıkış yapınca sıfırla
  void sifirla() {
    state = const ProfilState(durum: ProfilYukleme.yok);
  }
}

final profilProvider =
    StateNotifierProvider<ProfilNotifier, ProfilState>(
  (ref) => ProfilNotifier(),
);