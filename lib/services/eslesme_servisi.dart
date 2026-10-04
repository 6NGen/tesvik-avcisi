// lib/services/eslesme_servisi.dart
//
// Profil ↔ teşvik eşleştirme motoru. Ana liste, detay ekranı ve testler bu
// TEK kaynağı kullanır (eskiden detay ekranında farklı kurallı ikinci bir
// kopya vardı, iki ekran birbiriyle çelişiyordu).
//
// Kurallar:
//   • İl    : teşvikin il listesi varsa profilin ili içinde olmalı (ELER).
//   • Ürün  : teşvikin ürün listesi varsa en az bir ürün eşleşmeli (ELER).
//   • Tip   : etiketler üretici tipine uyuyorsa puan; uymuyorsa yalnızca not.
//   • Dekar : asgari dekar şartı varsa bilgi notu / puan.
// Python portu: scraper/push_bildirim.py → tesvik_profile_uyuyor (il + ürün).

import '../core/utils/metin.dart';
import '../models/profil_model.dart';
import '../models/tesvik_model.dart';

class EslesmeSonucu {
  final TesvikModel tesvik;
  final bool uygun; // eleyici kuralların hepsini geçti mi
  final double puan; // 0.0 – 1.0
  final List<String> nedenler; // ✓ uyan yönler
  final List<String> engeller; // ✗ eleyen yönler
  final List<String> notlar; // ℹ eleme yapmayan uyarılar

  const EslesmeSonucu({
    required this.tesvik,
    required this.uygun,
    required this.puan,
    required this.nedenler,
    required this.engeller,
    required this.notlar,
  });

  int get yuzde => (puan * 100).round();
}

class EslesmeServisi {
  EslesmeServisi._();

  static const _maks = 0.30 + 0.30 + 0.20 + 0.10;

  /// Tip → etiket anahtar kelimeleri (normalize, bkz. anahtarKelimeEslesir).
  static const Map<UreticiTipi, List<String>> tipAnahtarlari = {
    UreticiTipi.arici: ['ari', 'arici', 'bal', 'kovan', 'polen', 'propolis'],
    UreticiTipi.hayvancilik: [
      'hayvan', 'buyukbas', 'kucukbas', 'sut', 'besi', 'koyun', 'keci',
      'sigir', 'kumes', 'yem', 'balik', 'ahir',
    ],
    UreticiTipi.organik: ['organik', 'ekolojik'],
    UreticiTipi.ciftci: [
      'tarim', 'ciftci', 'bitkisel', 'tahil', 'tohum', 'sulama', 'mazot',
      'gubre', 'sera', 'fide', 'meyve', 'sebze', 'hasat', 'makine',
    ],
  };

  /// Bir teşviki profile göre değerlendirir (elense bile sonuç döner).
  static EslesmeSonucu degerlendir(TesvikModel tesvik, ProfilModel profil) {
    double puan = 0;
    var uygun = true;
    final nedenler = <String>[];
    final engeller = <String>[];
    final notlar = <String>[];

    // 1. İL
    if (tesvik.uygunIller.isNotEmpty) {
      if (tesvik.uygunIller.any((i) => ilEslesir(i, profil.il))) {
        puan += 0.30;
        nedenler.add('${profil.il} ilinde geçerli');
      } else {
        uygun = false;
        engeller.add(profil.il.isEmpty
            ? 'Belirli illere özel (profilinde il yok)'
            : '${profil.il} ilinde geçerli değil');
      }
    } else {
      puan += 0.15;
      nedenler.add('Tüm Türkiye\'de geçerli');
    }

    // 2. ÜRÜN
    if (tesvik.uygunUrunler.isNotEmpty) {
      final eslesen = profil.urunler
          .where((u) => tesvik.uygunUrunler.any((tu) => urunEslesir(u, tu)))
          .toList();
      if (eslesen.isNotEmpty) {
        puan += 0.30;
        nedenler.add('Ürünlerinle uyumlu: ${eslesen.take(3).join(", ")}');
      } else {
        uygun = false;
        engeller.add('Ürünlerinden hiçbiri kapsamda değil');
      }
    } else {
      puan += 0.15;
    }

    // 3. ÜRETİCİ TİPİ (eleme yapmaz)
    if (tesvik.etiketler.isNotEmpty) {
      final etiketKelimeleri = tesvik.etiketler.expand(kelimeler).toSet();
      final eslesenTip = profil.ureticiTipleri.where((tip) {
        final anahtarlar = tipAnahtarlari[tip] ?? const [];
        return etiketKelimeleri
            .any((k) => anahtarlar.any((a) => anahtarKelimeEslesir(k, a)));
      }).toList();
      if (eslesenTip.isNotEmpty) {
        puan += 0.20;
        nedenler.add(
            '${eslesenTip.map((t) => t.etiket).join(" / ")} kategorisinde destek');
      } else {
        puan += 0.05;
        notlar.add('Program üretim tipine özel görünmüyor');
      }
    } else {
      puan += 0.10;
    }

    // 4. ARAZİ (eleme yapmaz — veri her zaman güvenilir değil)
    final minDekar = tesvik.minDekar;
    if (minDekar != null && minDekar > 0) {
      final dekar = profil.dekar;
      if (dekar == null) {
        notlar.add('En az $minDekar dekar arazi şartı olabilir');
      } else if (dekar >= minDekar) {
        puan += 0.10;
        nedenler.add('Arazi büyüklüğün uygun ($minDekar+ dekar)');
      } else {
        notlar.add('En az $minDekar dekar isteniyor (sende ${dekar.round()})');
      }
    }

    return EslesmeSonucu(
      tesvik: tesvik,
      uygun: uygun,
      puan: (puan / _maks).clamp(0.0, 1.0),
      nedenler: nedenler,
      engeller: engeller,
      notlar: notlar,
    );
  }

  /// Yalnızca uygun teşvikler, puana göre azalan.
  static List<EslesmeSonucu> eslestir({
    required List<TesvikModel> tesvikler,
    required ProfilModel profil,
  }) {
    final sonuc = tesvikler
        .map((t) => degerlendir(t, profil))
        .where((s) => s.uygun)
        .toList()
      ..sort((a, b) => b.puan.compareTo(a.puan));
    return sonuc;
  }
}
