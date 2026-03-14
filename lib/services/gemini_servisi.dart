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
    ProfilModel? profil, // ← YENİ: profil opsiyonel
  }) async {
    final bugun = DateTime.now().toString().split(' ')[0];

    final tesvikMetni = tesvikler.isEmpty
        ? 'Sistemde aktif teşvik bulunamadı.'
        : tesvikler.map((t) => t.promptSatiri()).join('\n');

    // Profil varsa prompt'a ekle
    final profilMetni = profil != null
        ? '''
ÇİFTÇİ PROFİLİ (sistemde kayıtlı):
- Üretici tipi: ${profil.ureticiTipi.etiket}
- İl: ${profil.il}
- Ürünler: ${profil.urunler.join(', ')}
- ${profil.ureticiTipi == UreticiTipi.arici ? 'Kovan sayısı' : 'Arazi büyüklüğü'}: ${profil.dekarVeyaKovan != null ? '${profil.dekarVeyaKovan!.toInt()} ${profil.ureticiTipi == UreticiTipi.arici ? 'kovan' : 'dekar'}' : 'Belirtilmemiş'}

Bu profil bilgilerini belgedeki bilgilerle karşılaştır ve eşleşme analizini daha doğru yap.
'''
        : '';

    final promptStr = '''
Bugünün tarihi: $bugun. Sen profesyonel bir tarım danışmanısın.

$profilMetni
Çiftçinin yüklediği belgeyi incele ve aşağıdaki adımları uygula:

1. Belgeden okunan bilgilerle (varsa) profil bilgilerini karşılaştır, çiftçinin profilini özetle.
2. "SİSTEMDEKİ TEŞVİKLER" listesinden bu çiftçiye UYGUN olanları nedenleriyle açıkla.
3. UYGUN olmayan teşvikleri de kısaca belirt (neden uygun değil).
4. ÇOK ÖNEMLİ: Sadece UYGUN teşviklerin altına şu formatta link ekle:
[➔ HEMEN BAŞVURMAK İÇİN TIKLAYIN](linki_buraya_yaz)
5. Uygun bir teşvikin bitmesine 15 günden az kaldıysa metnin sonuna KRITIK_UYARI yaz.

SİSTEMDEKİ TEŞVİKLER:
$tesvikMetni
''';

    try {
      final response = await _model.generateContent([
        Content.multi([
          TextPart(promptStr),
          DataPart('image/jpeg', gorselBytes),
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
}