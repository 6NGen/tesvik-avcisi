// lib/providers/tesvik_provider.dart
//
// Teşvik listesi, filtre/arama durumu ve türetilmiş görünüm. Eşleştirme ve
// sıralama burada TEK KEZ hesaplanır; ekran yalnızca sonucu çizer.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/metin.dart';
import '../models/tesvik_model.dart';
import '../services/eslesme_servisi.dart';
import '../services/supabase_servisi.dart';
import 'profil_provider.dart';

final tesviklerProvider = StreamProvider<List<TesvikModel>>((ref) {
  return SupabaseServisi().tesviklerStream();
});

// ── CİHAZDA KALICI TERCİHLER ────────────────────────────────

class _KaliciKume extends StateNotifier<Set<String>> {
  final String _anahtar;
  _KaliciKume(this._anahtar) : super(const {}) {
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final kayitli = prefs.getStringList(_anahtar) ?? const [];
      if (mounted) state = {...state, ...kayitli};
    } catch (_) {}
  }

  Future<void> _kaydet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_anahtar, state.toList());
    } catch (_) {}
  }

  Future<void> ekle(String id) async {
    state = {...state, id};
    await _kaydet();
  }

  Future<void> cikar(String id) async {
    state = {...state}..remove(id);
    await _kaydet();
  }
}

/// Kullanıcının listeden gizlediği (süresi dolmuş) teşvikler.
final gizlenenTesviklerProvider =
    StateNotifierProvider<_KaliciKume, Set<String>>(
  (ref) => _KaliciKume('gizlenen_tesvikler'),
);

/// Kapatılan bilgi kartları (ör. 'cks').
final kapatilanKartlarProvider =
    StateNotifierProvider<_KaliciKume, Set<String>>(
  (ref) => _KaliciKume('kapatilan_kartlar'),
);

// ── FİLTRE / ARAMA ──────────────────────────────────────────

enum TesvikFiltre {
  uygun('Bana uygun'),
  tumu('Tümü'),
  yaklasan('Son tarihi yaklaşan');

  final String etiket;
  const TesvikFiltre(this.etiket);
}

final tesvikFiltreProvider =
    StateProvider<TesvikFiltre>((ref) => TesvikFiltre.uygun);
final tesvikAramaProvider = StateProvider<String>((ref) => '');

// ── TÜRETİLMİŞ GÖRÜNÜM ──────────────────────────────────────

class TesvikSatiri {
  final TesvikModel tesvik;
  final EslesmeSonucu? eslesme; // profil yoksa null
  const TesvikSatiri(this.tesvik, this.eslesme);

  bool get uygun => eslesme?.uygun ?? true;
}

class TesvikGorunumu {
  final List<TesvikSatiri> aktif; // filtre + aramadan geçen, süresi devam eden
  final List<TesvikSatiri> dolanlar; // süresi dolmuş (gizlenmemiş)
  final int toplamAktif; // tüm aktif teşvik sayısı
  final int uygunSayisi; // profile uygun, süresi devam eden
  final int yaklasanSayisi; // uygun ve 15 gün içinde bitecek
  final bool profilVar;

  const TesvikGorunumu({
    required this.aktif,
    required this.dolanlar,
    required this.toplamAktif,
    required this.uygunSayisi,
    required this.yaklasanSayisi,
    required this.profilVar,
  });
}

final tesvikGorunumuProvider = Provider<AsyncValue<TesvikGorunumu>>((ref) {
  final tesviklerAsync = ref.watch(tesviklerProvider);
  final profil = ref.watch(profilProvider.select((s) => s.profil));
  final gizlenen = ref.watch(gizlenenTesviklerProvider);
  final secilenFiltre = ref.watch(tesvikFiltreProvider);
  final arama = kelimeler(ref.watch(tesvikAramaProvider));

  return tesviklerAsync.whenData((tesvikler) {
    final satirlar = [
      for (final t in tesvikler)
        TesvikSatiri(
            t, profil == null ? null : EslesmeServisi.degerlendir(t, profil)),
    ];

    final devamEden = satirlar.where((s) => s.tesvik.sure.aktif).toList();
    final uygunlar = devamEden.where((s) => s.uygun).toList();

    // Profil yoksa "Bana uygun" filtresi anlamsız → Tümü gibi davran.
    final filtre = profil == null && secilenFiltre == TesvikFiltre.uygun
        ? TesvikFiltre.tumu
        : secilenFiltre;

    bool aramayaUyar(TesvikSatiri s) {
      if (arama.isEmpty) return true;
      final metin = kelimeler([
        s.tesvik.isim,
        s.tesvik.kurum ?? '',
        ...s.tesvik.etiketler,
        ...s.tesvik.uygunUrunler,
      ].join(' '));
      return arama.every((a) => metin.any((k) => k.startsWith(a)));
    }

    var aktif = switch (filtre) {
      TesvikFiltre.uygun => uygunlar,
      TesvikFiltre.tumu => devamEden,
      TesvikFiltre.yaklasan =>
        (profil == null ? devamEden : uygunlar)
            .where((s) => s.tesvik.sure.yaklasan)
            .toList(),
    }.where(aramayaUyar).toList();

    aktif.sort((a, b) => _karsilastir(a, b, filtre));

    final dolanlar = filtre == TesvikFiltre.yaklasan
        ? <TesvikSatiri>[]
        : (satirlar
            .where((s) =>
                !s.tesvik.sure.aktif &&
                !gizlenen.contains(s.tesvik.id) &&
                aramayaUyar(s))
            .toList()
          ..sort((a, b) =>
              b.tesvik.sonBasvuruTarihi!.compareTo(a.tesvik.sonBasvuruTarihi!)));

    return TesvikGorunumu(
      aktif: aktif,
      dolanlar: dolanlar,
      toplamAktif: devamEden.length,
      uygunSayisi: uygunlar.length,
      yaklasanSayisi: uygunlar.where((s) => s.tesvik.sure.yaklasan).length,
      profilVar: profil != null,
    );
  });
});

/// Sıralama: "yaklaşan" filtresinde en yakın tarih önce; diğerlerinde önce
/// uygunluk, sonra uyum puanı, sonra son tarih (süresizler sonda).
int _karsilastir(TesvikSatiri a, TesvikSatiri b, TesvikFiltre filtre) {
  if (filtre != TesvikFiltre.yaklasan) {
    if (a.uygun != b.uygun) return a.uygun ? -1 : 1;
    final pa = a.eslesme?.puan ?? 0, pb = b.eslesme?.puan ?? 0;
    if ((pa - pb).abs() > 0.001) return pb.compareTo(pa);
  }
  final ta = a.tesvik.sonBasvuruTarihi, tb = b.tesvik.sonBasvuruTarihi;
  if (ta == null && tb == null) return a.tesvik.isim.compareTo(b.tesvik.isim);
  if (ta == null) return 1;
  if (tb == null) return -1;
  return ta.compareTo(tb);
}
