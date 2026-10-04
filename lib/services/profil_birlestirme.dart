// lib/services/profil_birlestirme.dart
//
// Belge analizinden (PROFIL_JSON) gelen verilerle profil oluşturma/güncelleme.
// Saf fonksiyonlar — birim testlerle doğrulanır.

import '../models/profil_model.dart';

class ProfilBirlestirme {
  ProfilBirlestirme._();

  /// Mevcut profili belge verisiyle birleştirir. Belgede GEÇERLİ bulunan
  /// değerler öncelikli; bulunamayanlar ve bildirim tercihleri korunur.
  /// Hiçbir şey değişmiyorsa null döner (gereksiz DB yazımı yapılmaz).
  static ProfilModel? birlestir(ProfilModel mevcut, Map<String, dynamic> veri) {
    final yeni = mevcut.copyWith(
      il: ilDogrula(veri['il'] as String?),
      ureticiTipleri: tiplerCikar(veri),
      urunler: urunlerCikar(veri),
      dekar: sayiOku(veri['dekar']),
      kovanSayisi: sayiOku(veri['kovan_sayisi'])?.round(),
      hayvanSayisi: sayiOku(veri['hayvan_sayisi'])?.round(),
    );
    return _ayni(mevcut, yeni) ? null : yeni;
  }

  /// Belgeden sıfırdan profil oluşturur. En az il veya ürün bulunmalı.
  static ProfilModel? olustur(String userId, Map<String, dynamic> veri) {
    final il = ilDogrula(veri['il'] as String?) ?? '';
    final urunler = urunlerCikar(veri) ?? const <String>[];
    if (il.isEmpty && urunler.isEmpty) return null;
    return ProfilModel(
      userId: userId,
      ureticiTipleri: tiplerCikar(veri) ?? const [UreticiTipi.ciftci],
      il: il,
      urunler: urunler,
      dekar: sayiOku(veri['dekar']),
      kovanSayisi: sayiOku(veri['kovan_sayisi'])?.round(),
      hayvanSayisi: sayiOku(veri['hayvan_sayisi'])?.round(),
    );
  }

  /// Tanınan tipler; hiç tanınan yoksa null (bilinmeyen değer "çiftçi" sayılmaz).
  static List<UreticiTipi>? tiplerCikar(Map<String, dynamic> veri) {
    final raw = veri['uretici_tipleri'];
    if (raw is! List) return null;
    final liste =
        raw.map(UreticiTipi.adiyla).whereType<UreticiTipi>().toSet().toList();
    return liste.isEmpty ? null : liste;
  }

  static List<String>? urunlerCikar(Map<String, dynamic> veri) {
    final raw = veri['urunler'];
    if (raw is! List) return null;
    final gorulen = <String>{};
    final liste = <String>[];
    for (final s in raw.whereType<String>()) {
      final t = s.trim();
      if (t.isNotEmpty && gorulen.add(t.toLowerCase())) liste.add(t);
    }
    return liste.isEmpty ? null : liste;
  }

  static bool _ayni(ProfilModel a, ProfilModel b) =>
      a.il == b.il &&
      a.dekar == b.dekar &&
      a.kovanSayisi == b.kovanSayisi &&
      a.hayvanSayisi == b.hayvanSayisi &&
      _listeAyni(a.urunler, b.urunler) &&
      _listeAyni(a.ureticiTipleri, b.ureticiTipleri);

  static bool _listeAyni<T>(List<T> a, List<T> b) =>
      a.length == b.length && a.toSet().containsAll(b);
}
