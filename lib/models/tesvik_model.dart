// lib/models/tesvik_model.dart

class TesvikModel {
  final String id;
  final String isim;
  final String? kurum;
  final String? basvuruUrl;
  final DateTime? sonBasvuruTarihi;
  final List<String>? uygunIller;
  final List<String>? uygunUrunler;
  final List<String>? etiketler;
  final int? minDekar;

  const TesvikModel({
    required this.id,
    required this.isim,
    this.kurum,
    this.basvuruUrl,
    this.sonBasvuruTarihi,
    this.uygunIller,
    this.uygunUrunler,
    this.etiketler,
    this.minDekar,
  });

  factory TesvikModel.fromJson(Map<String, dynamic> json) {
    return TesvikModel(
      id: json['id']?.toString() ?? '',
      isim: json['isim'] as String? ?? 'İsimsiz Teşvik',
      kurum: json['kurum'] as String?,
      basvuruUrl: json['basvuru_url'] as String?,
      sonBasvuruTarihi: json['son_basvuru_tarihi'] != null
          ? DateTime.tryParse(json['son_basvuru_tarihi'].toString())
          : null,
      uygunIller: json['uygun_iller'] != null
          ? List<String>.from(json['uygun_iller'])
          : null,
      uygunUrunler: json['uygun_urunler'] != null
          ? List<String>.from(json['uygun_urunler'])
          : null,
      etiketler: json['etiketler'] != null
          ? List<String>.from(json['etiketler'])
          : null,
      minDekar: json['min_dekar'] as int?,
    );
  }

  // Gemini prompt satırı
  String promptSatiri() {
    return '- İsim: $isim'
        ' | Link: ${basvuruUrl ?? "Yok"}'
        ' | Son Tarih: ${sonBasvuruTarihi?.toString().split(" ")[0] ?? "Sürekli"}';
  }

  // Son başvuruya 15 günden az mı kaldı?
  bool get kritikTarihMi {
    if (sonBasvuruTarihi == null) return false;
    final kalan =
        sonBasvuruTarihi!.difference(DateTime.now()).inDays;
    return kalan >= 0 && kalan <= 15;
  }
}

// Gemini analiz sonucu
class AnalizSonucu {
  final String metin;
  final bool kritikUyariVar;
  final DateTime analizZamani;

  const AnalizSonucu({
    required this.metin,
    required this.kritikUyariVar,
    required this.analizZamani,
  });

  String get belgeOzeti =>
      'Belge Analizi - ${analizZamani.day}/${analizZamani.month}/${analizZamani.year}';

  String get temizMetin =>
      metin.replaceAll('KRITIK_UYARI', '').trim();
}

// Başvuru takipçisi modeli
class AnalizGecmisi {
  final String id;
  final String belgeOzeti;
  final String aiSonucu;
  final DateTime olusturulma;
  final String basvuruDurumu; // 'hazirlaniyor' | 'gonderildi' | 'sonuclandi'

  const AnalizGecmisi({
    required this.id,
    required this.belgeOzeti,
    required this.aiSonucu,
    required this.olusturulma,
    this.basvuruDurumu = 'hazirlaniyor',
  });

  factory AnalizGecmisi.fromJson(Map<String, dynamic> json) {
    return AnalizGecmisi(
      id: json['id']?.toString() ?? '',
      belgeOzeti: json['belge_ozeti'] as String? ?? 'Analiz',
      aiSonucu: json['ai_sonucu'] as String? ?? '',
      olusturulma: json['olusturulma'] != null
          ? DateTime.tryParse(json['olusturulma'].toString()) ??
              DateTime.now()
          : DateTime.now(),
      basvuruDurumu:
          json['basvuru_durumu'] as String? ?? 'hazirlaniyor',
    );
  }
}