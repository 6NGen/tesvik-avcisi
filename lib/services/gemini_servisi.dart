// lib/services/gemini_servisi.dart

import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../core/constants/app_constants.dart';
import '../models/tesvik_model.dart';
import '../models/profil_model.dart';

class GeminiServisi {
  static final GeminiServisi _instance = GeminiServisi._internal();
  factory GeminiServisi() => _instance;
  GeminiServisi._internal();

  late final GenerativeModel _model = GenerativeModel(
    model: AppConstants.geminiModel,
    apiKey: AppConstants.geminiApiKey,
  );

  Future<AnalizSonucu> belgeAnalizeEt({
    required Uint8List gorselBytes,
    required List<TesvikModel> tesvikler,
    ProfilModel? profil,
    String? dosyaAdi,
  }) async {
    final bugun = DateTime.now().toString().split(' ')[0];

    // Dosya tipini belirle
    final mimeType = _mimeTypeBelirle(gorselBytes, dosyaAdi ?? '');

    // Profil metni
    final profilMetni = profil != null
        ? '''
ÇİFTÇİ PROFİLİ (sistemde kayıtlı):
- Üretici tipi: ${profil.ureticiTipleri.map((t) => t.etiket).join(' + ')}
- İl: ${profil.il}
- Ürünler: ${profil.urunler.join(', ')}
${profil.dekar != null ? '- Arazi: ${profil.dekar!.toInt()} dekar' : ''}
${profil.kovanSayisi != null ? '- Kovan: ${profil.kovanSayisi} adet' : ''}
${profil.hayvanSayisi != null ? '- Hayvan: ${profil.hayvanSayisi} adet' : ''}
'''
        : '';

    final tesvikMetni = tesvikler.isEmpty
        ? 'Sistemde aktif teşvik bulunamadı.'
        : tesvikler.map((t) => t.promptSatiri()).join('\n');

    final promptStr = '''
Bugünün tarihi: $bugun. Sen profesyonel bir tarım danışmanısın.

$profilMetni
Yüklenen belgeyi (${dosyaAdi ?? 'belge'}) incele ve şunları yap:

1. Belgeden okunan bilgilerle profil bilgilerini karşılaştır, çiftçinin profilini özetle.
2. "SİSTEMDEKİ TEŞVİKLER" listesinden bu çiftçiye UYGUN olanları nedenleriyle açıkla.
3. UYGUN olmayan teşvikleri kısaca belirt.
4. Sadece UYGUN teşviklerin altına şu formatta link ekle:
[➔ HEMEN BAŞVURMAK İÇİN TIKLAYIN](linki_buraya_yaz)
5. Uygun bir teşvikin bitmesine 15 günden az kaldıysa metnin sonuna KRITIK_UYARI yaz.

SİSTEMDEKİ TEŞVİKLER:
$tesvikMetni
''';

    try {
      final response = await _model.generateContent([
        Content.multi([
          TextPart(promptStr),
          DataPart(mimeType, gorselBytes),
        ]),
      ]);

      final metin = response.text ?? 'Analiz sonucu alınamadı.';

      return AnalizSonucu(
        metin: metin,
        kritikUyariVar: metin.contains('KRITIK_UYARI'),
        analizZamani: DateTime.now(),
      );
    } on GenerativeAIException catch (e) {
      if (e.message.contains('429') || e.message.contains('quota')) {
        throw Exception(
            'Günlük AI analiz limiti doldu. Lütfen birkaç dakika bekleyin.');
      }
      throw Exception('AI hatası: ${e.message}');
    }
  }

  /// Dosya içeriğine ve adına göre MIME type belirle
  String _mimeTypeBelirle(Uint8List bytes, String dosyaAdi) {
    // PDF sihirli baytları: %PDF
    if (bytes.length > 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46) {
      return 'application/pdf';
    }
    // PNG
    if (bytes.length > 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50) {
      return 'image/png';
    }
    // JPEG
    if (bytes.length > 2 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8) {
      return 'image/jpeg';
    }
    // Uzantıya göre
    final uzanti = dosyaAdi.split('.').last.toLowerCase();
    switch (uzanti) {
      case 'pdf': return 'application/pdf';
      case 'png': return 'image/png';
      default: return 'image/jpeg';
    }
  }
}