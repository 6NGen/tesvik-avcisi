// lib/models/profil_model.dart

// Üretici tipleri
enum UreticiTipi {
  ciftci('Çiftçi', '🌾'),
  arici('Arıcı', '🐝'),
  hayvancilik('Hayvancı', '🐄'),
  organik('Organik Üretici', '🌿');

  final String etiket;
  final String emoji;
  const UreticiTipi(this.etiket, this.emoji);
}

// Tipe göre ürün listeleri
const Map<UreticiTipi, List<String>> tipUrunleri = {
  UreticiTipi.ciftci: [
    'Buğday', 'Arpa', 'Mısır', 'Ayçiçeği', 'Pamuk',
    'Domates', 'Biber', 'Patates', 'Soğan', 'Şeker Pancarı',
  ],
  UreticiTipi.arici: [
    'Süzme Bal', 'Petek Bal', 'Ana Arı', 'Polen', 'Propolis', 'Arı Sütü',
  ],
  UreticiTipi.hayvancilik: [
    'Büyükbaş (Süt)', 'Büyükbaş (Et)', 'Küçükbaş', 'Kümes Hayvanları', 'Su Ürünleri',
  ],
  UreticiTipi.organik: [
    'Organik Tahıl', 'Organik Sebze', 'Organik Meyve',
    'Organik Bal', 'Organik Süt Ürünleri',
  ],
};

// Kullanıcı profili — Supabase'e kaydedilecek
class ProfilModel {
  final String userId;
  final UreticiTipi ureticiTipi;
  final String il;
  final List<String> urunler;
  final double? dekarVeyaKovan; // çiftçi → dekar, arıcı → kovan sayısı

  const ProfilModel({
    required this.userId,
    required this.ureticiTipi,
    required this.il,
    required this.urunler,
    this.dekarVeyaKovan,
  });

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'uretici_tipi': ureticiTipi.name,
        'il': il,
        'urunler': urunler,
        'dekar_veya_kovan': dekarVeyaKovan,
        'guncelleme': DateTime.now().toIso8601String(),
      };

  factory ProfilModel.fromJson(Map<String, dynamic> json) {
    return ProfilModel(
      userId: json['user_id'] as String,
      ureticiTipi: UreticiTipi.values.firstWhere(
        (t) => t.name == json['uretici_tipi'],
        orElse: () => UreticiTipi.ciftci,
      ),
      il: json['il'] as String? ?? '',
      urunler: List<String>.from(json['urunler'] ?? []),
      dekarVeyaKovan: (json['dekar_veya_kovan'] as num?)?.toDouble(),
    );
  }

  // Gemini prompt'una eklenecek profil özeti
  String promptOzeti() {
    final miktar = dekarVeyaKovan != null
        ? ureticiTipi == UreticiTipi.arici
            ? '${dekarVeyaKovan!.toInt()} kovan'
            : '${dekarVeyaKovan!.toInt()} dekar'
        : '';
    return '$il ilinde ${ureticiTipi.etiket.toLowerCase()} — '
        '${urunler.join(", ")} $miktar';
  }
}

// Türkiye illeri listesi
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