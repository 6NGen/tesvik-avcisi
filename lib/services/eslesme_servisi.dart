// lib/services/eslesme_servisi.dart
// Profil bilgisiyle teşvikleri eşleştiren motor.
// Puan sistemi: İl + Ürün + Tip + Miktar → toplam skor

import '../models/tesvik_model.dart';
import '../models/profil_model.dart';

class EslesmeSonucu {
  final TesvikModel tesvik;
  final double puan;       // 0.0 - 1.0
  final List<String> nedenler; // Neden uyuyor

  const EslesmeSonucu({
    required this.tesvik,
    required this.puan,
    required this.nedenler,
  });
}

class EslesmeServisi {
  /// Profil + teşvik listesini karşılaştır, puanlı sonuç döndür
  static List<EslesmeSonucu> eslestir({
    required List<TesvikModel> tesvikler,
    required ProfilModel profil,
  }) {
    final sonuclar = <EslesmeSonucu>[];

    for (final tesvik in tesvikler) {
      final sonuc = _puanla(tesvik: tesvik, profil: profil);
      if (sonuc != null) sonuclar.add(sonuc);
    }

    // Puana göre büyükten küçüğe sırala
    sonuclar.sort((a, b) => b.puan.compareTo(a.puan));
    return sonuclar;
  }

  static EslesmeSonucu? _puanla({
    required TesvikModel tesvik,
    required ProfilModel profil,
  }) {
    double puan = 0.0;
    final nedenler = <String>[];

    // ── 1. İL KONTROLÜ ─────────────────────────────────────
    if (tesvik.uygunIller != null && tesvik.uygunIller!.isNotEmpty) {
      if (!tesvik.uygunIller!.contains(profil.il)) {
        return null; // Bu ile uygun değil, tamamen elendi
      }
      puan += 0.30;
      nedenler.add('📍 ${profil.il} iline özel destek');
    } else {
      puan += 0.15; // Tüm Türkiye için geçerli
      nedenler.add('🇹🇷 Tüm Türkiye\'de geçerli');
    }

    // ── 2. ÜRÜN KONTROLÜ ────────────────────────────────────
    if (tesvik.uygunUrunler != null && tesvik.uygunUrunler!.isNotEmpty) {
      final eslesenUrunler = profil.urunler
          .where((u) => tesvik.uygunUrunler!.any(
                (tu) => tu.toLowerCase() == u.toLowerCase(),
              ))
          .toList();

      if (eslesenUrunler.isEmpty) {
        return null; // Hiçbir ürün eşleşmedi, elendi
      }
      puan += 0.30;
      nedenler.add('🌾 ${eslesenUrunler.take(2).join(", ")} ürünlerinize uygun');
    } else {
      puan += 0.15; // Tüm ürünler için geçerli
    }

    // ── 3. ÜRETİCİ TİPİ KONTROLÜ ───────────────────────────
    if (tesvik.etiketler != null && tesvik.etiketler!.isNotEmpty) {
      bool tipEslesti = false;

      for (final tip in profil.ureticiTipleri) {
        final tipAnahtarlari = _tipAnahtarlari(tip);
        if (tesvik.etiketler!.any((e) =>
            tipAnahtarlari.any((k) => e.toLowerCase().contains(k)))) {
          tipEslesti = true;
          puan += 0.20;
          nedenler.add('${tip.emoji} ${tip.etiket} desteği');
          break;
        }
      }

      // Tip eşleşmesi yoksa düşük puan ver ama eleme
      if (!tipEslesti) puan += 0.05;
    } else {
      puan += 0.10;
    }

    // ── 4. MİKTAR KONTROLÜ ──────────────────────────────────
    if (tesvik.minDekar != null && profil.dekar != null) {
      if (profil.dekar! >= tesvik.minDekar!) {
        puan += 0.10;
        nedenler.add('📐 Arazi büyüklüğünüz uygun');
      }
    }

    // Minimum puan eşiği — çok düşük puanlıları gösterme
    if (puan < 0.20) return null;

    return EslesmeSonucu(
      tesvik: tesvik,
      puan: puan.clamp(0.0, 1.0),
      nedenler: nedenler,
    );
  }

  static List<String> _tipAnahtarlari(UreticiTipi tip) {
    switch (tip) {
      case UreticiTipi.arici:
        return ['arıcılık', 'arı', 'bal', 'kovan'];
      case UreticiTipi.hayvancilik:
        return ['hayvancılık', 'hayvan', 'büyükbaş', 'küçükbaş', 'süt'];
      case UreticiTipi.organik:
        return ['organik', 'ekolojik'];
      case UreticiTipi.ciftci:
        return ['tahıl', 'tarım', 'çiftçi', 'bitkisel'];
    }
  }
}