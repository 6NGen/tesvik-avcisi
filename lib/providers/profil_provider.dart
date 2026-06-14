// lib/providers/profil_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profil_model.dart';
import 'auth_provider.dart';

// Profil yükleme durumu
enum ProfilYukleme { yukleniyor, var_, yok, hata }

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

  // Yükleme sırasında hata mı oluştu? (ağ vb. — profilin yok olduğu anlamına gelmez)
  bool get profilHata => durum == ProfilYukleme.hata;
}

class ProfilNotifier extends StateNotifier<ProfilState> {
  // Başlatma artık authProvider listener'ı tarafından yapılır (bkz. profilProvider).
  // Constructor'da otomatik yükleme YOK — aksi halde açılışta çift yükleme olurdu.
  ProfilNotifier()
      : super(const ProfilState(durum: ProfilYukleme.yukleniyor));

  final _client = Supabase.instance.client;

  // En son profili yüklenen kullanıcı id'si. Aynı kullanıcı için gelen
  // tekrarlı auth olaylarını (token yenileme, userUpdated) ayıklamak için.
  String? _yukluUserId;

  /// authProvider değişince çağrılır. Yalnızca kullanıcı GERÇEKTEN değiştiğinde
  /// profili yeniden yükler; aynı id ile gelen olayları sessizce yok sayar.
  void authDegisti(User? user) {
    if (user == null) {
      // Oturum yok / çıkış yapıldı
      _yukluUserId = null;
      if (state.durum != ProfilYukleme.yok) {
        state = const ProfilState(durum: ProfilYukleme.yok);
      }
      return;
    }
    // Aynı kullanıcı (ör. saatlik token yenileme) → tekrar yükleme yapma
    if (user.id == _yukluUserId) return;
    _yukluUserId = user.id;
    _profilYukle();
  }

  Future<void> _profilYukle() async {
    final user = _client.auth.currentUser;

    // Kullanıcı giriş yapmamış → profil yok (yükleme gerekmiyor)
    if (user == null) {
      state = const ProfilState(durum: ProfilYukleme.yok);
      return;
    }

    // DB sorgusu sürerken state 'yok' kalırsa _AppRouter ProfilEkrani'nı bir an
    // gösterir (flaş). Sorgu başlamadan önce 'yukleniyor'a çek.
    if (!state.yukleniyor) {
      state = const ProfilState(durum: ProfilYukleme.yukleniyor);
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
              response),
        );
      }
    } catch (e) {
      // Ağ/sorgu hatası → profili "yok" sayma (kullanıcıyı profil oluşturma
      // ekranına atmamalı). Ayrı bir hata durumu ver; mevcut profil korunur.
      debugPrint('Profil yüklenemedi: $e');
      state = const ProfilState(durum: ProfilYukleme.hata);
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

  // Bildirim tercihini güncelle (Ayarlar'daki switch'ler). Optimistik:
  // önce yerel state, sonra DB'ye yazılır. Push servisi bu kolonları okuyacak.
  Future<void> bildirimTercihiAyarla({bool? sonTarih, bool? yeniHibe}) async {
    final mevcut = state.profil;
    if (mevcut == null) return;
    final yeni = mevcut.copyWith(
      bildirimSonTarih: sonTarih,
      bildirimYeniHibe: yeniHibe,
    );
    state = ProfilState(durum: ProfilYukleme.var_, profil: yeni);
    try {
      final guncelleme = <String, dynamic>{};
      if (sonTarih != null) guncelleme['bildirim_son_tarih'] = sonTarih;
      if (yeniHibe != null) guncelleme['bildirim_yeni_hibe'] = yeniHibe;
      await _client
          .from('kullanici_profilleri')
          .update(guncelleme)
          .eq('user_id', mevcut.userId);
    } catch (e) {
      debugPrint('Bildirim tercihi kaydedilemedi: $e');
    }
  }

  // Profili yeniden yükle (giriş yapınca manuel çağrılır). Guard'ı da günceller
  // ki sonrasında gelen signedIn auth olayı aynı id ile tekrar yükleme yapmasın.
  Future<void> yenile() {
    _yukluUserId = _client.auth.currentUser?.id;
    return _profilYukle();
  }

  // Çıkış yapınca sıfırla
  void sifirla() {
    _yukluUserId = null;
    state = const ProfilState(durum: ProfilYukleme.yok);
  }
}

final profilProvider =
    StateNotifierProvider<ProfilNotifier, ProfilState>((ref) {
  final notifier = ProfilNotifier();
  // Auth durumunu dinle (watch DEĞİL — watch notifier'ı her token yenilemesinde
  // yeniden yaratır). fireImmediately: provider geç yaratılıp auth zaten
  // çözülmüşse ilk değeri kaçırmamak için.
  ref.listen<AsyncValue<User?>>(
    authProvider,
    (previous, next) => notifier.authDegisti(next.valueOrNull),
    fireImmediately: true,
  );
  return notifier;
});