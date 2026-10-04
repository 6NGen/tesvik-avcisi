// lib/models/tesvik_model.dart

import '../core/utils/tarih.dart';

class TesvikModel {
  final String id;
  final String isim;
  final String? kurum;
  final String? basvuruUrl;
  final DateTime? sonBasvuruTarihi;
  final List<String> uygunIller; // boş = tüm Türkiye
  final List<String> uygunUrunler; // boş = tüm ürünler
  final List<String> etiketler;
  final int? minDekar;

  const TesvikModel({
    required this.id,
    required this.isim,
    this.kurum,
    this.basvuruUrl,
    this.sonBasvuruTarihi,
    this.uygunIller = const [],
    this.uygunUrunler = const [],
    this.etiketler = const [],
    this.minDekar,
  });

  factory TesvikModel.fromJson(Map<String, dynamic> json) {
    final url = (json['basvuru_url'] as String?)?.trim();
    final kurum = (json['kurum'] as String?)?.trim();
    return TesvikModel(
      id: json['id']?.toString() ?? '',
      isim: (json['isim'] as String?)?.trim().isNotEmpty == true
          ? (json['isim'] as String).trim()
          : 'İsimsiz Teşvik',
      kurum: kurum == null || kurum.isEmpty ? null : kurum,
      basvuruUrl: url == null || url.isEmpty ? null : url,
      sonBasvuruTarihi: json['son_basvuru_tarihi'] != null
          ? DateTime.tryParse(json['son_basvuru_tarihi'].toString())
          : null,
      uygunIller: _liste(json['uygun_iller']),
      uygunUrunler: _liste(json['uygun_urunler']),
      etiketler: _liste(json['etiketler']),
      minDekar: (json['min_dekar'] as num?)?.toInt(),
    );
  }

  /// null, liste ya da tek metin gelebilir; boş/null elemanlar atılır.
  static List<String> _liste(Object? v) {
    if (v is List) {
      return v
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (v is String && v.trim().isNotEmpty) return [v.trim()];
    return const [];
  }

  bool get tumTurkiye => uygunIller.isEmpty;
  int? get kalan => kalanGun(sonBasvuruTarihi);
  SureDurumu get sure => sureDurumu(sonBasvuruTarihi);
}

// Gemini analiz sonucu
class AnalizSonucu {
  final String metin;
  final bool kritikUyariVar;
  final DateTime analizZamani;
  final Map<String, dynamic>? cikarilanProfil; // belgeden çekilen profil verisi
  final String? dosyaAdi;

  const AnalizSonucu({
    required this.metin,
    required this.kritikUyariVar,
    required this.analizZamani,
    this.cikarilanProfil,
    this.dosyaAdi,
  });

  /// Takip listesinde görünen başlık. "Belge Analizi" öneki AnalizGecmisi'nin
  /// kayıt türünü ayırt etmesi için kullanılır.
  String get belgeOzeti => dosyaAdi == null || dosyaAdi!.isEmpty
      ? '$belgeAnaliziOneki · ${tarihUzun(analizZamani)}'
      : '$belgeAnaliziOneki · $dosyaAdi';

  /// KRITIK_UYARI ve PROFIL_JSON satırını kullanıcıya gösterme
  String get temizMetin => analizMetniTemizle(metin);
}

const belgeAnaliziOneki = 'Belge Analizi';

String analizMetniTemizle(String metin) => metin
    .replaceAll('KRITIK_UYARI', '')
    .replaceAll(RegExp(r'PROFIL_JSON:\s*\{[^\n]*\}'), '')
    .trim();

/// Başvuru durumları (analiz_gecmisi.basvuru_durumu)
enum BasvuruDurumu {
  hazirlaniyor('Hazırlanıyor'),
  gonderildi('Gönderildi'),
  sonuclandi('Sonuçlandı');

  final String etiket;
  const BasvuruDurumu(this.etiket);

  static BasvuruDurumu adiyla(String? ad) => values.firstWhere(
        (d) => d.name == ad,
        orElse: () => BasvuruDurumu.hazirlaniyor,
      );
}

// Takip kaydı: ya bir belge analizi ya da "başvuruya başladım" denmiş teşvik.
class AnalizGecmisi {
  final String id;
  final String belgeOzeti;
  final String aiSonucu;
  final DateTime olusturulma;
  final BasvuruDurumu basvuruDurumu;

  const AnalizGecmisi({
    required this.id,
    required this.belgeOzeti,
    required this.aiSonucu,
    required this.olusturulma,
    this.basvuruDurumu = BasvuruDurumu.hazirlaniyor,
  });

  bool get belgeAnaliziMi => belgeOzeti.startsWith(belgeAnaliziOneki);

  AnalizGecmisi durumla(BasvuruDurumu d) => AnalizGecmisi(
        id: id,
        belgeOzeti: belgeOzeti,
        aiSonucu: aiSonucu,
        olusturulma: olusturulma,
        basvuruDurumu: d,
      );

  factory AnalizGecmisi.fromJson(Map<String, dynamic> json) {
    return AnalizGecmisi(
      id: json['id']?.toString() ?? '',
      belgeOzeti: json['belge_ozeti'] as String? ?? belgeAnaliziOneki,
      aiSonucu: json['ai_sonucu'] as String? ?? '',
      olusturulma:
          DateTime.tryParse(json['olusturulma']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
      basvuruDurumu: BasvuruDurumu.adiyla(json['basvuru_durumu'] as String?),
    );
  }
}
