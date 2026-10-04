// lib/models/profil_model.dart

import 'package:flutter/material.dart';
import '../core/utils/metin.dart';

enum UreticiTipi {
  ciftci('Çiftçi', '🌾', Icons.agriculture_rounded),
  arici('Arıcı', '🐝', Icons.hive_rounded),
  hayvancilik('Hayvancı', '🐄', Icons.pets_rounded),
  organik('Organik', '🌿', Icons.eco_rounded);

  final String etiket;
  final String emoji;
  final IconData ikon;
  const UreticiTipi(this.etiket, this.emoji, this.ikon);

  /// DB/Gemini değerinden tip; tanınmayan değer için null (eskiden sessizce
  /// "çiftçi" sayılıyordu).
  static UreticiTipi? adiyla(Object? ad) {
    final s = ad?.toString().trim();
    for (final t in values) {
      if (t.name == s) return t;
    }
    return null;
  }
}

// Tipe göre ürün listeleri
const Map<UreticiTipi, List<String>> tipUrunleri = {
  UreticiTipi.ciftci: [
    'Buğday', 'Arpa', 'Mısır', 'Ayçiçeği', 'Pamuk',
    'Domates', 'Biber', 'Patates', 'Soğan', 'Şeker Pancarı',
    'Zeytin', 'Üzüm', 'Fındık', 'Kiraz', 'Elma',
  ],
  UreticiTipi.arici: [
    'Süzme Bal', 'Petek Bal', 'Ana Arı',
    'Polen', 'Propolis', 'Arı Sütü',
  ],
  UreticiTipi.hayvancilik: [
    'Büyükbaş (Süt)', 'Büyükbaş (Et)',
    'Küçükbaş (Koyun)', 'Küçükbaş (Keçi)',
    'Kümes Hayvanları', 'Su Ürünleri',
  ],
  UreticiTipi.organik: [
    'Organik Tahıl', 'Organik Sebze',
    'Organik Meyve', 'Organik Bal',
    'Organik Süt Ürünleri',
  ],
};

class ProfilModel {
  final String userId;
  final List<UreticiTipi> ureticiTipleri; // Çoklu tip
  final String il;
  final List<String> urunler;
  final double? dekar;
  final int? kovanSayisi;
  final int? hayvanSayisi;
  final bool bildirimSonTarih; // son başvuru tarihi hatırlatmaları
  final bool bildirimYeniHibe; // yeni hibe bildirimleri

  const ProfilModel({
    required this.userId,
    required this.ureticiTipleri,
    required this.il,
    required this.urunler,
    this.dekar,
    this.kovanSayisi,
    this.hayvanSayisi,
    this.bildirimSonTarih = true,
    this.bildirimYeniHibe = true,
  });

  ProfilModel copyWith({
    List<UreticiTipi>? ureticiTipleri,
    String? il,
    List<String>? urunler,
    double? dekar,
    int? kovanSayisi,
    int? hayvanSayisi,
    bool? bildirimSonTarih,
    bool? bildirimYeniHibe,
  }) =>
      ProfilModel(
        userId: userId,
        ureticiTipleri: ureticiTipleri ?? this.ureticiTipleri,
        il: il ?? this.il,
        urunler: urunler ?? this.urunler,
        dekar: dekar ?? this.dekar,
        kovanSayisi: kovanSayisi ?? this.kovanSayisi,
        hayvanSayisi: hayvanSayisi ?? this.hayvanSayisi,
        bildirimSonTarih: bildirimSonTarih ?? this.bildirimSonTarih,
        bildirimYeniHibe: bildirimYeniHibe ?? this.bildirimYeniHibe,
      );

  String get tipEtiketleri => ureticiTipleri.map((t) => t.etiket).join(' · ');
  bool get ariciMi => ureticiTipleri.contains(UreticiTipi.arici);
  bool get hayvanciMi => ureticiTipleri.contains(UreticiTipi.hayvancilik);
  bool get araziliMi =>
      ureticiTipleri.contains(UreticiTipi.ciftci) ||
      ureticiTipleri.contains(UreticiTipi.organik);

  /// "120 dekar · 40 kovan" (boş olabilir)
  String get miktarOzeti => [
        if (dekar != null) '${_sayi(dekar!)} dekar',
        if (kovanSayisi != null) '$kovanSayisi kovan',
        if (hayvanSayisi != null) '$hayvanSayisi hayvan',
      ].join(' · ');

  static String _sayi(double d) =>
      d == d.roundToDouble() ? d.toInt().toString() : d.toStringAsFixed(1);

  /// Bildirim tercihleri ayrı (bildirimTercihiAyarla) yazılır; upsert onları
  /// ezmesin diye burada YOK.
  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'uretici_tipleri': ureticiTipleri.map((t) => t.name).toList(),
        'uretici_tipi':
            (ureticiTipleri.isEmpty ? UreticiTipi.ciftci : ureticiTipleri.first)
                .name, // geriye dönük
        'il': il,
        'urunler': urunler,
        'dekar': dekar,
        'kovan_sayisi': kovanSayisi,
        'hayvan_sayisi': hayvanSayisi,
        'guncelleme': DateTime.now().toIso8601String(),
      };

  factory ProfilModel.fromJson(Map<String, dynamic> json) {
    var tipler = <UreticiTipi>[];
    final ham = json['uretici_tipleri'];
    if (ham is List) {
      tipler = ham.map(UreticiTipi.adiyla).whereType<UreticiTipi>().toList();
    }
    if (tipler.isEmpty) {
      final eski = UreticiTipi.adiyla(json['uretici_tipi']);
      tipler = [eski ?? UreticiTipi.ciftci];
    }

    return ProfilModel(
      userId: json['user_id'] as String,
      ureticiTipleri: tipler.toSet().toList(),
      il: json['il'] as String? ?? '',
      urunler: _stringListe(json['urunler']),
      dekar: sayiOku(json['dekar']),
      kovanSayisi: sayiOku(json['kovan_sayisi'])?.round(),
      hayvanSayisi: sayiOku(json['hayvan_sayisi'])?.round(),
      // Kolon yoksa (migration öncesi) varsayılan açık.
      bildirimSonTarih: json['bildirim_son_tarih'] as bool? ?? true,
      bildirimYeniHibe: json['bildirim_yeni_hibe'] as bool? ?? true,
    );
  }
}

List<String> _stringListe(Object? v) => v is List
    ? v.whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
    : <String>[];

/// num, "12", "12.5", "12,5" → double; geçersiz/negatif → null.
/// (Gemini sayıları bazen 12.0 ya da metin olarak döndürüyor; eskiden
/// `as int?` cast'i patlayıp profil güncellemesini sessizce iptal ediyordu.)
double? sayiOku(Object? v) {
  double? d;
  if (v is num) d = v.toDouble();
  if (v is String) d = double.tryParse(v.trim().replaceAll(',', '.'));
  if (d == null || d.isNaN || d.isInfinite || d < 0) return null;
  return d;
}

// Türkiye illeri (alfabetik)
const List<String> turkiyeIlleri = [
  'Adana', 'Adıyaman', 'Afyonkarahisar', 'Ağrı', 'Aksaray', 'Amasya',
  'Ankara', 'Antalya', 'Ardahan', 'Artvin', 'Aydın', 'Balıkesir',
  'Bartın', 'Batman', 'Bayburt', 'Bilecik', 'Bingöl', 'Bitlis',
  'Bolu', 'Burdur', 'Bursa', 'Çanakkale', 'Çankırı', 'Çorum',
  'Denizli', 'Diyarbakır', 'Düzce', 'Edirne', 'Elazığ', 'Erzincan',
  'Erzurum', 'Eskişehir', 'Gaziantep', 'Giresun', 'Gümüşhane', 'Hakkari',
  'Hatay', 'Iğdır', 'Isparta', 'İstanbul', 'İzmir', 'Kahramanmaraş',
  'Karabük', 'Karaman', 'Kars', 'Kastamonu', 'Kayseri', 'Kırıkkale',
  'Kırklareli', 'Kırşehir', 'Kilis', 'Kocaeli', 'Konya', 'Kütahya',
  'Malatya', 'Manisa', 'Mardin', 'Mersin', 'Muğla', 'Muş',
  'Nevşehir', 'Niğde', 'Ordu', 'Osmaniye', 'Rize', 'Sakarya',
  'Samsun', 'Siirt', 'Sinop', 'Sivas', 'Şanlıurfa', 'Şırnak',
  'Tekirdağ', 'Tokat', 'Trabzon', 'Tunceli', 'Uşak', 'Van',
  'Yalova', 'Yozgat', 'Zonguldak',
];

/// Ham (örn. Gemini'den gelen) bir il değerini doğrular ve normalize eder.
/// Geçerliyse `turkiyeIlleri` içindeki KANONİK adı döndürür, değilse null.
/// "Ankara/Polatlı" → "Ankara", "06 Ankara" → "Ankara", "ANKARA" → "Ankara".
String? ilDogrula(String? ham) {
  if (ham == null) return null;
  var s = ham.trim();
  if (s.isEmpty) return null;
  if (s.contains('/')) s = s.split('/').first.trim();
  s = s.replaceFirst(RegExp(r'^\d+\s*'), '').trim();
  if (s.isEmpty) return null;
  final anahtar = turkceAnahtar(s);
  for (final il in turkiyeIlleri) {
    if (turkceAnahtar(il) == anahtar) return il;
  }
  return null;
}

/// İki il adını Türkçe-duyarlı şekilde karşılaştırır. Boş/null → false.
bool ilEslesir(String? a, String? b) {
  if (a == null || b == null) return false;
  final ka = turkceAnahtar(a);
  final kb = turkceAnahtar(b);
  if (ka.isEmpty || kb.isEmpty) return false;
  return ka == kb;
}
