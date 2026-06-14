// lib/models/profil_model.dart

enum UreticiTipi {
  ciftci('Çiftçi', '🌾'),
  arici('Arıcı', '🐝'),
  hayvancilik('Hayvancı', '🐄'),
  organik('Organik', '🌿');

  final String etiket;
  final String emoji;
  const UreticiTipi(this.etiket, this.emoji);
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
    String? userId,
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
        userId: userId ?? this.userId,
        ureticiTipleri: ureticiTipleri ?? this.ureticiTipleri,
        il: il ?? this.il,
        urunler: urunler ?? this.urunler,
        dekar: dekar ?? this.dekar,
        kovanSayisi: kovanSayisi ?? this.kovanSayisi,
        hayvanSayisi: hayvanSayisi ?? this.hayvanSayisi,
        bildirimSonTarih: bildirimSonTarih ?? this.bildirimSonTarih,
        bildirimYeniHibe: bildirimYeniHibe ?? this.bildirimYeniHibe,
      );

  // Geriye dönük uyumluluk için
  UreticiTipi get ureticiTipi =>
      ureticiTipleri.isNotEmpty ? ureticiTipleri.first : UreticiTipi.ciftci;

  // Tüm tiplerin emoji'leri
  String get tipEmojileri =>
      ureticiTipleri.map((t) => t.emoji).join('');

  // Arıcı mı?
  bool get ariciMi => ureticiTipleri.contains(UreticiTipi.arici);

  // Hayvancı mı?
  bool get hayvancimi =>
      ureticiTipleri.contains(UreticiTipi.hayvancilik);

  // Çiftçi mi?
  bool get ciftciMi => ureticiTipleri.contains(UreticiTipi.ciftci);

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'uretici_tipleri':
            ureticiTipleri.map((t) => t.name).toList(),
        'uretici_tipi': ureticiTipleri.first.name, // geriye dönük
        'il': il,
        'urunler': urunler,
        'dekar': dekar,
        'kovan_sayisi': kovanSayisi,
        'hayvan_sayisi': hayvanSayisi,
        'guncelleme': DateTime.now().toIso8601String(),
      };

  factory ProfilModel.fromJson(Map<String, dynamic> json) {
    // Çoklu tip (yeni format)
    List<UreticiTipi> tipler = [];
    if (json['uretici_tipleri'] != null) {
      tipler = (json['uretici_tipleri'] as List<dynamic>)
          .map((t) => UreticiTipi.values.firstWhere(
                (e) => e.name == t,
                orElse: () => UreticiTipi.ciftci,
              ))
          .toList();
    }
    // Eski format (geriye dönük uyumluluk)
    if (tipler.isEmpty && json['uretici_tipi'] != null) {
      tipler = [
        UreticiTipi.values.firstWhere(
          (t) => t.name == json['uretici_tipi'],
          orElse: () => UreticiTipi.ciftci,
        )
      ];
    }
    if (tipler.isEmpty) tipler = [UreticiTipi.ciftci];

    return ProfilModel(
      userId: json['user_id'] as String,
      ureticiTipleri: tipler,
      il: json['il'] as String? ?? '',
      urunler: List<String>.from(json['urunler'] ?? []),
      dekar: (json['dekar'] as num?)?.toDouble(),
      kovanSayisi: (json['kovan_sayisi'] as num?)?.toInt(),
      hayvanSayisi: (json['hayvan_sayisi'] as num?)?.toInt(),
      // Kolon yoksa (migration öncesi) varsayılan açık.
      bildirimSonTarih: json['bildirim_son_tarih'] as bool? ?? true,
      bildirimYeniHibe: json['bildirim_yeni_hibe'] as bool? ?? true,
    );
  }

  // Gemini prompt özeti
  String promptOzeti() {
    final tipler =
        ureticiTipleri.map((t) => t.etiket).join(' + ');
    final miktarlar = [
      if (dekar != null) '${dekar!.toInt()} dekar',
      if (kovanSayisi != null) '$kovanSayisi kovan',
      if (hayvanSayisi != null) '$hayvanSayisi hayvan',
    ].join(', ');
    return '$il ilinde $tipler — ${urunler.join(", ")} $miktarlar';
  }
}

// Türkiye illeri
const List<String> turkiyeIlleri = [
  'Adana', 'Adıyaman', 'Afyonkarahisar', 'Ağrı', 'Amasya',
  'Ankara', 'Antalya', 'Artvin', 'Aydın', 'Balıkesir',
  'Bilecik', 'Bingöl', 'Bitlis', 'Bolu', 'Burdur',
  'Bursa', 'Çanakkale', 'Çankırı', 'Çorum', 'Denizli',
  'Diyarbakır', 'Edirne', 'Elazığ', 'Erzincan', 'Erzurum',
  'Eskişehir', 'Gaziantep', 'Giresun', 'Gümüşhane', 'Hakkari',
  'Hatay', 'Isparta', 'Mersin', 'İstanbul', 'İzmir',
  'Kars', 'Kastamonu', 'Kayseri', 'Kırklareli', 'Kırşehir',
  'Kocaeli', 'Konya', 'Kütahya', 'Malatya', 'Manisa',
  'Kahramanmaraş', 'Mardin', 'Muğla', 'Muş', 'Nevşehir',
  'Niğde', 'Ordu', 'Rize', 'Sakarya', 'Samsun',
  'Siirt', 'Sinop', 'Sivas', 'Tekirdağ', 'Tokat',
  'Trabzon', 'Tunceli', 'Şanlıurfa', 'Uşak', 'Van',
  'Yozgat', 'Zonguldak', 'Aksaray', 'Bayburt', 'Karaman',
  'Kırıkkale', 'Batman', 'Şırnak', 'Bartın', 'Ardahan',
  'Iğdır', 'Yalova', 'Karabük', 'Kilis', 'Osmaniye', 'Düzce',
];

// ── İL NORMALLEŞTİRME / DOĞRULAMA ──────────────────────────────────
// İl adlarını Türkçe büyük-küçük harf duyarlılığından bağımsız karşılaştırmak
// için ortak anahtar üretir. Dart'ın toLowerCase()'i Türkçe İ/I için güvenilir
// olmadığından bu harfler önce açıkça ASCII karşılıklarına katlanır.
// Örn: "İSTANBUL", "istanbul", "İstanbul" → "istanbul"; "Iğdır" → "igdir".
String _ilAnahtar(String s) {
  const harita = {
    'ç': 'c', 'Ç': 'c',
    'ğ': 'g', 'Ğ': 'g',
    'ı': 'i', 'İ': 'i', 'I': 'i',
    'ö': 'o', 'Ö': 'o',
    'ş': 's', 'Ş': 's',
    'ü': 'u', 'Ü': 'u',
  };
  final sb = StringBuffer();
  for (final ch in s.trim().split('')) {
    sb.write(harita[ch] ?? ch);
  }
  return sb.toString().toLowerCase();
}

/// Ham (örn. Gemini'den gelen) bir il değerini doğrular ve normalize eder.
/// Geçerliyse `turkiyeIlleri` içindeki KANONİK adı döndürür, değilse null.
/// "Ankara/Polatlı" → "Ankara", "06 Ankara" → "Ankara", "ANKARA" → "Ankara".
String? ilDogrula(String? ham) {
  if (ham == null) return null;
  var s = ham.trim();
  if (s.isEmpty) return null;
  // "Ankara/Polatlı" gibi alt-bölge → ilk parça
  if (s.contains('/')) s = s.split('/').first.trim();
  // "06 Ankara" gibi baştaki plaka kodu/rakamları temizle
  s = s.replaceFirst(RegExp(r'^\d+\s*'), '').trim();
  if (s.isEmpty) return null;
  final anahtar = _ilAnahtar(s);
  for (final il in turkiyeIlleri) {
    if (_ilAnahtar(il) == anahtar) return il;
  }
  return null;
}

/// İki il adını Türkçe-duyarlı şekilde karşılaştırır. Boş/null → false.
bool ilEslesir(String? a, String? b) {
  if (a == null || b == null) return false;
  final ka = _ilAnahtar(a);
  final kb = _ilAnahtar(b);
  if (ka.isEmpty || kb.isEmpty) return false;
  return ka == kb;
}