// lib/services/gemini_servisi.dart
//
// Gemini çağrısı artık Supabase Edge Function (belge-analiz) üzerinden yapılır.
// API anahtarı istemcide TUTULMAZ; prompt ve teşvik listesi sunucuda kurulur (K3).

import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tesvik_model.dart';
import '../models/profil_model.dart';

class GeminiServisi {
  static final GeminiServisi _instance = GeminiServisi._internal();
  factory GeminiServisi() => _instance;
  GeminiServisi._internal();

  // Edge Function payload'ı için makul üst sınır (base64 ~%33 şişer).
  static const int _maksBoyut = 5 * 1024 * 1024; // 5 MB

  Future<AnalizSonucu> belgeAnalizeEt({
    required Uint8List gorselBytes,
    ProfilModel? profil,
    String? dosyaAdi,
  }) async {
    final client = Supabase.instance.client;

    // Giriş zorunlu (Edge Function da ayrıca doğrular).
    if (client.auth.currentUser == null) {
      throw Exception('Belge analizi için giriş yapmanız gerekiyor.');
    }
    if (gorselBytes.length > _maksBoyut) {
      throw Exception(
          'Dosya çok büyük (en fazla 5 MB). Daha küçük bir görsel/PDF yükleyin.');
    }

    final mimeType = _mimeTypeBelirle(gorselBytes, dosyaAdi ?? '');

    final profilGirdi = profil == null
        ? null
        : {
            'tipler': profil.ureticiTipleri.map((t) => t.etiket).join(' + '),
            'il': profil.il,
            'urunler': profil.urunler,
            'dekar': profil.dekar?.toInt(),
            'kovanSayisi': profil.kovanSayisi,
            'hayvanSayisi': profil.hayvanSayisi,
          };

    try {
      final response = await client.functions.invoke(
        'belge-analiz',
        body: {
          'gorselBase64': base64Encode(gorselBytes),
          'mimeType': mimeType,
          'dosyaAdi': dosyaAdi,
          'profil': profilGirdi,
        },
      );

      final data = response.data;
      final metin = (data is Map && data['metin'] is String)
          ? data['metin'] as String
          : 'Analiz sonucu alınamadı.';
      final cikarilanProfil = _profilJsonCikar(metin);

      return AnalizSonucu(
        metin: metin,
        kritikUyariVar: metin.contains('KRITIK_UYARI'),
        analizZamani: DateTime.now(),
        cikarilanProfil: cikarilanProfil,
      );
    } on FunctionException catch (e) {
      // Edge Function {error: ...} gövdesini kullanıcıya yansıt.
      final detay = (e.details is Map && (e.details as Map)['error'] is String)
          ? (e.details as Map)['error'] as String
          : 'AI analizi başarısız. Lütfen tekrar deneyin.';
      throw Exception(detay);
    }
  }

  /// Gemini çıktısından PROFIL_JSON satırını parse eder
  Map<String, dynamic>? _profilJsonCikar(String metin) {
    final regex = RegExp(r'PROFIL_JSON:(\{[^\n]+\})');
    final match = regex.firstMatch(metin);
    if (match == null) return null;
    try {
      return jsonDecode(match.group(1)!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Dosya içeriğine ve adına göre MIME type belirle
  String _mimeTypeBelirle(Uint8List bytes, String dosyaAdi) {
    if (bytes.length > 4 &&
        bytes[0] == 0x25 && bytes[1] == 0x50 &&
        bytes[2] == 0x44 && bytes[3] == 0x46) {
      return 'application/pdf';
    }
    if (bytes.length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50) {
      return 'image/png';
    }
    if (bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return 'image/jpeg';
    }
    final uzanti = dosyaAdi.split('.').last.toLowerCase();
    switch (uzanti) {
      case 'pdf': return 'application/pdf';
      case 'png': return 'image/png';
      default: return 'image/jpeg';
    }
  }
}
