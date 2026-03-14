// lib/providers/ocr_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/tesvik_model.dart';
import '../models/profil_model.dart';
import '../services/gemini_servisi.dart';
import '../services/supabase_servisi.dart';
import 'profil_provider.dart';

class OcrState {
  final bool yukleniyor;
  final AnalizSonucu? sonuc;
  final String? hata;

  const OcrState({
    this.yukleniyor = false,
    this.sonuc,
    this.hata,
  });

  bool get bos => !yukleniyor && sonuc == null && hata == null;

  OcrState copyWith({bool? yukleniyor, AnalizSonucu? sonuc, String? hata}) =>
      OcrState(
        yukleniyor: yukleniyor ?? this.yukleniyor,
        sonuc: sonuc ?? this.sonuc,
        hata: hata ?? this.hata,
      );
}

class OcrNotifier extends StateNotifier<OcrState> {
  final GeminiServisi _gemini = GeminiServisi();
  final SupabaseServisi _db = SupabaseServisi();
  final ImagePicker _picker = ImagePicker();
  final Ref _ref;

  OcrNotifier(this._ref) : super(const OcrState());

  Future<void> gorselSecVeAnalizeEt() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    state = state.copyWith(yukleniyor: true, hata: null);

    try {
      final gorselBytes = await image.readAsBytes();
      final tesvikler = await _db.tesvikleriGetir();

      // Profil bilgisini al
      final ProfilModel? profil = _ref.read(profilProvider).value;

      // Gemini'ye profil ile birlikte gönder
      final sonuc = await _gemini.belgeAnalizeEt(
        gorselBytes: gorselBytes,
        tesvikler: tesvikler,
        profil: profil,
      );

      await _db.analiziKaydet(sonuc);
      state = state.copyWith(yukleniyor: false, sonuc: sonuc);
    } catch (e) {
      state = OcrState(hata: e.toString());
    }
  }

  void sifirla() => state = const OcrState();
}

final ocrProvider = StateNotifierProvider<OcrNotifier, OcrState>(
  (ref) => OcrNotifier(ref),
);