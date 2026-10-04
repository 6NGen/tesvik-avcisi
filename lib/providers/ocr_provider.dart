// lib/providers/ocr_provider.dart

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/mesaj.dart';
import '../models/tesvik_model.dart';
import '../services/gemini_servisi.dart';
import '../services/profil_birlestirme.dart';
import '../services/supabase_servisi.dart';
import 'auth_provider.dart';
import 'profil_provider.dart';
import 'takip_provider.dart';

class OcrState {
  final bool yukleniyor;
  final AnalizSonucu? sonuc;
  final String? hata;
  final String? dosyaAdi;
  final bool profilGuncellendi; // analiz sonrası profil güncellendiyse true
  final bool kaydedildi; // takip listesine kaydedildi mi

  const OcrState({
    this.yukleniyor = false,
    this.sonuc,
    this.hata,
    this.dosyaAdi,
    this.profilGuncellendi = false,
    this.kaydedildi = false,
  });

  bool get bos => !yukleniyor && sonuc == null && hata == null;
}

class OcrNotifier extends StateNotifier<OcrState> {
  final GeminiServisi _gemini = GeminiServisi();
  final SupabaseServisi _db = SupabaseServisi();
  final Ref _ref;

  OcrNotifier(this._ref) : super(const OcrState());

  /// Dosya seç, Gemini ile analiz et, takibe kaydet, profili güncelle.
  Future<void> dosyaSecVeAnalizeEt() async {
    if (state.yukleniyor) return;

    final FilePickerResult? secim;
    try {
      secim = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
    } catch (_) {
      state = const OcrState(hata: 'Dosya seçici açılamadı.');
      return;
    }
    if (secim == null || secim.files.isEmpty) return;

    final dosya = secim.files.first;
    final bytes = dosya.bytes;
    if (bytes == null) {
      state = const OcrState(hata: 'Dosya okunamadı. Tekrar dene.');
      return;
    }
    if (bytes.length > GeminiServisi.maksBoyut) {
      state = const OcrState(
          hata: 'Dosya çok büyük (en fazla 5 MB). Daha küçük bir dosya seç.');
      return;
    }

    final userId = _ref.read(kullaniciIdProvider);
    state = OcrState(yukleniyor: true, dosyaAdi: dosya.name);

    try {
      final mevcutProfil = _ref.read(profilProvider).profil;
      final sonuc = await _gemini.belgeAnalizeEt(
        gorselBytes: bytes,
        profil: mevcutProfil,
        dosyaAdi: dosya.name,
      );
      // Analiz sürerken oturum değiştiyse sonucu bırak.
      if (!mounted || _ref.read(kullaniciIdProvider) != userId) return;

      var kaydedildi = false;
      try {
        await _db.analiziKaydet(sonuc);
        kaydedildi = true;
        _ref.invalidate(takipProvider);
      } catch (_) {/* analiz sonucu yine de gösterilir */}

      final guncellendi = await _profilGuncelle(sonuc, userId);

      if (!mounted) return;
      state = OcrState(
        sonuc: sonuc,
        dosyaAdi: dosya.name,
        profilGuncellendi: guncellendi,
        kaydedildi: kaydedildi,
      );
    } catch (e) {
      if (!mounted) return;
      state = OcrState(hata: hataMetni(e), dosyaAdi: dosya.name);
    }
  }

  Future<bool> _profilGuncelle(AnalizSonucu sonuc, String? userId) async {
    final veri = sonuc.cikarilanProfil;
    if (veri == null || userId == null) return false;
    final mevcut = _ref.read(profilProvider).profil;
    final yeni = mevcut != null
        ? ProfilBirlestirme.birlestir(mevcut, veri)
        : ProfilBirlestirme.olustur(userId, veri);
    if (yeni == null) return false;
    return _ref.read(profilProvider.notifier).profilKaydet(yeni);
  }

  void sifirla() => state = const OcrState();
}

final ocrProvider = StateNotifierProvider<OcrNotifier, OcrState>((ref) {
  final notifier = OcrNotifier(ref);
  // Kullanıcı değişince (çıkış / başka hesap) önceki analiz ekranda kalmasın.
  ref.listen<String?>(kullaniciIdProvider, (onceki, sonraki) {
    if (onceki != sonraki) notifier.sifirla();
  });
  return notifier;
});
