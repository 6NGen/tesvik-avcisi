// lib/providers/profil_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profil_model.dart';
import 'auth_provider.dart';

enum ProfilYukleme { yukleniyor, var_, yok, hata }

class ProfilState {
  final ProfilYukleme durum;
  final ProfilModel? profil;

  const ProfilState({required this.durum, this.profil});

  bool get yukleniyor => durum == ProfilYukleme.yukleniyor;
  bool get profilVar => durum == ProfilYukleme.var_;
  bool get profilYok => durum == ProfilYukleme.yok;
  bool get profilHata => durum == ProfilYukleme.hata;
}

class ProfilNotifier extends StateNotifier<ProfilState> {
  // Başlatma authProvider listener'ı tarafından yapılır (bkz. profilProvider).
  ProfilNotifier() : super(const ProfilState(durum: ProfilYukleme.yukleniyor));

  final _client = Supabase.instance.client;

  // En son profili yüklenen kullanıcı. Aynı kullanıcı için gelen tekrarlı auth
  // olaylarını (token yenileme, userUpdated) ayıklamak için.
  String? _yukluUserId;

  void authDegisti(User? user) {
    if (user == null) {
      _yukluUserId = null;
      if (state.durum != ProfilYukleme.yok) {
        state = const ProfilState(durum: ProfilYukleme.yok);
      }
      return;
    }
    if (user.id == _yukluUserId) return;
    _yukluUserId = user.id;
    _profilYukle();
  }

  Future<void> _profilYukle() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      state = const ProfilState(durum: ProfilYukleme.yok);
      return;
    }
    // Sorgu sürerken 'yok' kalırsa kök yönlendirici profil sihirbazını bir an
    // gösterir (flaş). Önce 'yukleniyor'a çek.
    if (!state.yukleniyor) {
      state = const ProfilState(durum: ProfilYukleme.yukleniyor);
    }
    try {
      final response = await _client
          .from('kullanici_profilleri')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      // Bu sırada kullanıcı değiştiyse (çıkış/başka hesap) sonucu yazma.
      if (_client.auth.currentUser?.id != user.id) return;
      state = response == null
          ? const ProfilState(durum: ProfilYukleme.yok)
          : ProfilState(
              durum: ProfilYukleme.var_,
              profil: ProfilModel.fromJson(response),
            );
    } catch (e) {
      // Ağ/sorgu hatası → profili "yok" sayma (kullanıcıyı sihirbaza atmamalı).
      debugPrint('Profil yüklenemedi: $e');
      state = const ProfilState(durum: ProfilYukleme.hata);
    }
  }

  /// Profili kaydeder. Bildirim tercihleri upsert'e dahil değildir; yerel
  /// state'te mevcut tercihler korunur (eskiden ekranda sıfırlanıyordu).
  Future<bool> profilKaydet(ProfilModel profil) async {
    final eski = state.profil;
    final kaydedilecek = eski == null
        ? profil
        : profil.copyWith(
            bildirimSonTarih: eski.bildirimSonTarih,
            bildirimYeniHibe: eski.bildirimYeniHibe,
          );
    try {
      await _client
          .from('kullanici_profilleri')
          .upsert(kaydedilecek.toJson(), onConflict: 'user_id');
      state = ProfilState(durum: ProfilYukleme.var_, profil: kaydedilecek);
      return true;
    } catch (e) {
      debugPrint('Profil kaydedilemedi: $e');
      return false;
    }
  }

  /// Bildirim tercihi (optimistik). DB'ye yazılamazsa geri alınır ve false döner.
  Future<bool> bildirimTercihiAyarla({bool? sonTarih, bool? yeniHibe}) async {
    final mevcut = state.profil;
    if (mevcut == null) return false;
    state = ProfilState(
      durum: ProfilYukleme.var_,
      profil: mevcut.copyWith(
          bildirimSonTarih: sonTarih, bildirimYeniHibe: yeniHibe),
    );
    try {
      await _client.from('kullanici_profilleri').update({
        'bildirim_son_tarih': ?sonTarih,
        'bildirim_yeni_hibe': ?yeniHibe,
      }).eq('user_id', mevcut.userId);
      return true;
    } catch (e) {
      debugPrint('Bildirim tercihi kaydedilemedi: $e');
      state = ProfilState(durum: ProfilYukleme.var_, profil: mevcut);
      return false;
    }
  }

  /// Girişten hemen sonra / hata sonrası yeniden deneme.
  Future<void> yenile() {
    _yukluUserId = _client.auth.currentUser?.id;
    return _profilYukle();
  }

  void sifirla() {
    _yukluUserId = null;
    state = const ProfilState(durum: ProfilYukleme.yok);
  }
}

final profilProvider =
    StateNotifierProvider<ProfilNotifier, ProfilState>((ref) {
  final notifier = ProfilNotifier();
  // listen (watch değil): watch notifier'ı her token yenilemesinde yeniden
  // yaratırdı. fireImmediately: auth zaten çözülmüşse ilk değeri kaçırmamak için.
  ref.listen<AsyncValue<User?>>(
    authProvider,
    (_, next) {
      if (next.isLoading) return;
      notifier.authDegisti(next.valueOrNull);
    },
    fireImmediately: true,
  );
  return notifier;
});
