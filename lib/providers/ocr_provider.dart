// lib/providers/ocr_provider.dart

import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tesvik_model.dart';
import '../models/profil_model.dart';
import '../services/gemini_servisi.dart';
import '../services/supabase_servisi.dart';
import 'profil_provider.dart';

class OcrState {
  final bool yukleniyor;
  final AnalizSonucu? sonuc;
  final String? hata;
  final String? dosyaAdi;
  final bool profilGuncellendi; // analiz sonrası profil güncellendiyse true

  const OcrState({
    this.yukleniyor = false,
    this.sonuc,
    this.hata,
    this.dosyaAdi,
    this.profilGuncellendi = false,
  });

  bool get bos => !yukleniyor && sonuc == null && hata == null;

  OcrState copyWith({
    bool? yukleniyor,
    AnalizSonucu? sonuc,
    String? hata,
    String? dosyaAdi,
    bool? profilGuncellendi,
  }) =>
      OcrState(
        yukleniyor: yukleniyor ?? this.yukleniyor,
        sonuc: sonuc ?? this.sonuc,
        hata: hata ?? this.hata,
        dosyaAdi: dosyaAdi ?? this.dosyaAdi,
        profilGuncellendi: profilGuncellendi ?? this.profilGuncellendi,
      );
}

class OcrNotifier extends StateNotifier<OcrState> {
  final GeminiServisi _gemini = GeminiServisi();
  final SupabaseServisi _db = SupabaseServisi();
  final Ref _ref;

  OcrNotifier(this._ref) : super(const OcrState());

  /// Dosya seç, Gemini ile analiz et, profili otomatik güncelle
  Future<void> dosyaSecVeAnalizeEt() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final dosya = result.files.first;
    final bytes = dosya.bytes;

    if (bytes == null) {
      state = OcrState(hata: 'Dosya okunamadı. Tekrar deneyin.');
      return;
    }

    state = state.copyWith(
      yukleniyor: true,
      hata: null,
      dosyaAdi: dosya.name,
      profilGuncellendi: false,
    );

    try {
      final tesvikler = await _db.tesvikleriGetir();
      final ProfilModel? mevcutProfil = _ref.read(profilProvider).profil;

      final sonuc = await _gemini.belgeAnalizeEt(
        gorselBytes: bytes,
        tesvikler: tesvikler,
        profil: mevcutProfil,
        dosyaAdi: dosya.name,
      );

      await _db.analiziKaydet(sonuc);

      // Profil otomatik güncelleme
      final bool guncellendi = await _profilGuncelle(sonuc, mevcutProfil);

      state = state.copyWith(
        yukleniyor: false,
        sonuc: sonuc,
        profilGuncellendi: guncellendi,
      );
    } catch (e) {
      state = OcrState(hata: e.toString());
    }
  }

  /// Gemini'den çekilen profil verisiyle mevcut profili güncelle
  Future<bool> _profilGuncelle(AnalizSonucu sonuc, ProfilModel? mevcutProfil) async {
    final veri = sonuc.cikarilanProfil;
    if (veri == null) return false;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;

    try {
      final ProfilModel yeniProfil;

      if (mevcutProfil != null) {
        // Mevcut profil var → belgeden gelen verilerle birleştir
        yeniProfil = _profilBirlestir(mevcutProfil, veri);
      } else {
        // Profil yok → belgeden oluştur
        final olusturulan = _profilOlustur(user.id, veri);
        if (olusturulan == null) return false;
        yeniProfil = olusturulan;
      }

      return await _ref.read(profilProvider.notifier).profilKaydet(yeniProfil);
    } catch (_) {
      return false;
    }
  }

  /// Mevcut profil ile belge verisini birleştir
  /// Belgede bulunan değerler öncelikli, bulunamayanlar mevcut değerde kalır
  ProfilModel _profilBirlestir(ProfilModel mevcut, Map<String, dynamic> veri) {
    // il: belgede varsa güncelle
    final il = (veri['il'] as String?)?.isNotEmpty == true
        ? veri['il'] as String
        : mevcut.il;

    // uretici_tipleri: belgede varsa güncelle
    final tipler = _tiplerCikar(veri) ?? mevcut.ureticiTipleri;

    // urunler: belgede varsa güncelle
    final urunler = _urunlerCikar(veri) ?? mevcut.urunler;

    // sayısal alanlar: belgede varsa güncelle, yoksa mevcut değer
    final dekar = (veri['dekar'] as num?)?.toDouble() ?? mevcut.dekar;
    final kovanSayisi = veri['kovan_sayisi'] as int? ?? mevcut.kovanSayisi;
    final hayvanSayisi = veri['hayvan_sayisi'] as int? ?? mevcut.hayvanSayisi;

    return ProfilModel(
      userId: mevcut.userId,
      ureticiTipleri: tipler,
      il: il,
      urunler: urunler,
      dekar: dekar,
      kovanSayisi: kovanSayisi,
      hayvanSayisi: hayvanSayisi,
    );
  }

  /// Belgeden sıfırdan profil oluştur (en az il veya tip olmalı)
  ProfilModel? _profilOlustur(String userId, Map<String, dynamic> veri) {
    final il = veri['il'] as String? ?? '';
    final tipler = _tiplerCikar(veri) ?? [UreticiTipi.ciftci];
    final urunler = _urunlerCikar(veri) ?? [];

    // Minimum veri yoksa oluşturma
    if (il.isEmpty && urunler.isEmpty) return null;

    return ProfilModel(
      userId: userId,
      ureticiTipleri: tipler,
      il: il,
      urunler: urunler,
      dekar: (veri['dekar'] as num?)?.toDouble(),
      kovanSayisi: veri['kovan_sayisi'] as int?,
      hayvanSayisi: veri['hayvan_sayisi'] as int?,
    );
  }

  /// JSON'dan UreticiTipi listesi çıkar
  List<UreticiTipi>? _tiplerCikar(Map<String, dynamic> veri) {
    final raw = veri['uretici_tipleri'];
    if (raw == null) return null;
    final liste = (raw as List<dynamic>)
        .map((t) => UreticiTipi.values.firstWhere(
              (e) => e.name == t.toString(),
              orElse: () => UreticiTipi.ciftci,
            ))
        .toList();
    return liste.isEmpty ? null : liste;
  }

  /// JSON'dan ürün listesi çıkar
  List<String>? _urunlerCikar(Map<String, dynamic> veri) {
    final raw = veri['urunler'];
    if (raw == null) return null;
    final liste = List<String>.from(raw as List<dynamic>);
    return liste.isEmpty ? null : liste;
  }

  void sifirla() => state = const OcrState();
}

final ocrProvider = StateNotifierProvider<OcrNotifier, OcrState>(
  (ref) => OcrNotifier(ref),
);