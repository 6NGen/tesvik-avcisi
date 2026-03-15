// lib/providers/ocr_provider.dart

import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  const OcrState({
    this.yukleniyor = false,
    this.sonuc,
    this.hata,
    this.dosyaAdi,
  });

  bool get bos => !yukleniyor && sonuc == null && hata == null;

  OcrState copyWith({
    bool? yukleniyor,
    AnalizSonucu? sonuc,
    String? hata,
    String? dosyaAdi,
  }) =>
      OcrState(
        yukleniyor: yukleniyor ?? this.yukleniyor,
        sonuc: sonuc ?? this.sonuc,
        hata: hata ?? this.hata,
        dosyaAdi: dosyaAdi ?? this.dosyaAdi,
      );
}

class OcrNotifier extends StateNotifier<OcrState> {
  final GeminiServisi _gemini = GeminiServisi();
  final SupabaseServisi _db = SupabaseServisi();
  final Ref _ref;

  OcrNotifier(this._ref) : super(const OcrState());

  /// Dosya seçici — PDF, JPG, PNG destekli
  Future<void> dosyaSecVeAnalizeEt() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true, // Dosya byte'larını belleğe al
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
    );

    try {
      final tesvikler = await _db.tesvikleriGetir();
      final ProfilModel? profil = _ref.read(profilProvider).profil;

      // PDF ise görsel olarak gönder (Gemini Vision destekliyor)
      final gorselBytes = _dosyaHazirla(bytes, dosya.extension ?? '');

      final sonuc = await _gemini.belgeAnalizeEt(
        gorselBytes: gorselBytes,
        tesvikler: tesvikler,
        profil: profil,
        dosyaAdi: dosya.name,
      );

      await _db.analiziKaydet(sonuc);
      state = state.copyWith(yukleniyor: false, sonuc: sonuc);
    } catch (e) {
      state = OcrState(hata: e.toString());
    }
  }

  /// Dosya tipine göre byte'ları hazırla
  Uint8List _dosyaHazirla(Uint8List bytes, String uzanti) {
    // PDF ve görsel formatları direkt gönder
    return bytes;
  }

  void sifirla() => state = const OcrState();
}

final ocrProvider = StateNotifierProvider<OcrNotifier, OcrState>(
  (ref) => OcrNotifier(ref),
);