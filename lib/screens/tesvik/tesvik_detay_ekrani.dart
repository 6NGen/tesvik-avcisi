// lib/screens/tesvik/tesvik_detay_ekrani.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../models/tesvik_model.dart';
import '../../models/profil_model.dart';
import '../../providers/profil_provider.dart';
import '../../services/supabase_servisi.dart';

class TesvikDetayEkrani extends ConsumerWidget {
  final TesvikModel tesvik;

  const TesvikDetayEkrani({super.key, required this.tesvik});

  int? get _kalanGun {
    if (tesvik.sonBasvuruTarihi == null) return null;
    return tesvik.sonBasvuruTarihi!.difference(DateTime.now()).inDays;
  }

  Color _uyariRengi() {
    final kalan = _kalanGun;
    if (kalan == null) return AppTheme.ormanYesili;
    if (kalan <= 3) return Colors.red.shade600;
    if (kalan <= 7) return Colors.orange.shade600;
    if (kalan <= 15) return Colors.amber.shade600;
    return AppTheme.ormanYesili;
  }

  /// Profilin bu teşvikle gerçek uyumunu hesaplar
  _UyumSonucu _uyumHesapla(ProfilModel profil) {
    final nedenler = <String>[];
    final uyumsuzlar = <String>[];

    // 1. İL KONTROLÜ
    if (tesvik.uygunIller != null && tesvik.uygunIller!.isNotEmpty) {
      if (tesvik.uygunIller!.contains(profil.il)) {
        nedenler.add('📍 ${profil.il} ilinizde geçerli');
      } else {
        uyumsuzlar.add('📍 ${profil.il} ilinizde geçerli değil');
      }
    } else {
      nedenler.add('🇹🇷 Tüm Türkiye\'de geçerli');
    }

    // 2. ÜRÜN KONTROLÜ
    if (tesvik.uygunUrunler != null && tesvik.uygunUrunler!.isNotEmpty) {
      final eslesenUrunler = profil.urunler
          .where((u) => tesvik.uygunUrunler!.any(
                (tu) => tu.toLowerCase() == u.toLowerCase(),
              ))
          .toList();

      if (eslesenUrunler.isNotEmpty) {
        nedenler.add('🌾 ${eslesenUrunler.take(2).join(", ")} ürününüzle uyumlu');
      } else {
        uyumsuzlar.add('🌾 Ürünlerinizle uyumsuz');
      }
    }

    // 3. ETİKET / ÜRETİCİ TİPİ KONTROLÜ
    if (tesvik.etiketler != null && tesvik.etiketler!.isNotEmpty) {
      final tipAnahtarlari = {
        UreticiTipi.arici: ['arıcılık', 'arı', 'bal', 'kovan'],
        UreticiTipi.hayvancilik: ['hayvancılık', 'hayvan', 'büyükbaş', 'küçükbaş', 'süt'],
        UreticiTipi.organik: ['organik', 'ekolojik'],
        UreticiTipi.ciftci: ['tahıl', 'tarım', 'çiftçi', 'bitkisel', 'mazot', 'gübre'],
      };

      bool tipEslesti = false;
      for (final tip in profil.ureticiTipleri) {
        final anahtarlar = tipAnahtarlari[tip] ?? [];
        if (tesvik.etiketler!.any((e) =>
            anahtarlar.any((k) => e.toLowerCase().contains(k)))) {
          tipEslesti = true;
          nedenler.add('${tip.emoji} ${tip.etiket} kategorisinde destek');
          break;
        }
      }

      // Tip eşleşmedi ama etiketler var — genel program
      if (!tipEslesti && uyumsuzlar.isEmpty && nedenler.length <= 1) {
        return _UyumSonucu(
          uyumlu: false,
          nedenler: [],
          uyumsuzlar: ['Bu program sizin üretim tipinize özel değil'],
          genelProgram: true,
        );
      }
    }

    // Hiç kriter yoksa genel program
    if (tesvik.uygunUrunler == null &&
        tesvik.uygunIller == null &&
        (tesvik.etiketler == null || tesvik.etiketler!.isEmpty)) {
      return _UyumSonucu(
        uyumlu: true,
        nedenler: ['🌐 Tüm üreticilere açık genel destek programı'],
        uyumsuzlar: [],
        genelProgram: true,
      );
    }

    return _UyumSonucu(
      uyumlu: uyumsuzlar.isEmpty,
      nedenler: nedenler,
      uyumsuzlar: uyumsuzlar,
      genelProgram: false,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profil = ref.watch(profilProvider).profil;
    final kalan = _kalanGun;

    return Scaffold(
      backgroundColor: AppTheme.cimensoluk,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppTheme.ormanYesili,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.ormanYesili, AppTheme.ortaYesil],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (tesvik.kurum != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(tesvik.kurum!,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          tesvik.isim,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Son başvuru tarihi
                  if (tesvik.sonBasvuruTarihi != null)
                    _BilgiKarti(
                      ikon: kalan != null && kalan <= 15 ? '⚠️' : '📅',
                      baslik: 'Son Başvuru Tarihi',
                      deger:
                          '${tesvik.sonBasvuruTarihi!.day}/${tesvik.sonBasvuruTarihi!.month}/${tesvik.sonBasvuruTarihi!.year}',
                      alt: kalan != null
                          ? kalan <= 0
                              ? 'Süre doldu'
                              : '$kalan gün kaldı'
                          : null,
                      renkli: kalan != null && kalan <= 15,
                      renk: _uyariRengi(),
                    ),

                  if (tesvik.sonBasvuruTarihi != null)
                    const SizedBox(height: 12),

                  // Uygun ürünler
                  if (tesvik.uygunUrunler != null &&
                      tesvik.uygunUrunler!.isNotEmpty) ...[
                    _EtiketKarti(
                      baslik: '🌾 Uygun Ürünler',
                      etiketler: tesvik.uygunUrunler!,
                      renk: AppTheme.yaprakAcik,
                      textRenk: AppTheme.ormanYesili,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Uygun iller
                  if (tesvik.uygunIller != null &&
                      tesvik.uygunIller!.isNotEmpty) ...[
                    _EtiketKarti(
                      baslik: '📍 Uygun İller',
                      etiketler: tesvik.uygunIller!,
                      renk: const Color(0xFFE3F2FD),
                      textRenk: const Color(0xFF1565C0),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (tesvik.uygunIller == null ||
                      tesvik.uygunIller!.isEmpty) ...[
                    _BilgiKarti(
                      ikon: '🇹🇷',
                      baslik: 'Kapsam',
                      deger: 'Tüm Türkiye',
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Profil uyumu — sadece giriş yapılmışsa
                  if (profil != null) ...[
                    _ProfilUyumKarti(uyum: _uyumHesapla(profil)),
                    const SizedBox(height: 12),
                  ],

                  // Etiketler
                  if (tesvik.etiketler != null &&
                      tesvik.etiketler!.isNotEmpty) ...[
                    _EtiketKarti(
                      baslik: '🏷️ Kategoriler',
                      etiketler: tesvik.etiketler!,
                      renk: const Color(0xFFF3E5F5),
                      textRenk: const Color(0xFF6A1B9A),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Başvur butonu
                  if (tesvik.basvuruUrl != null)
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(tesvik.basvuruUrl!);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        },
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text(
                          'Resmi Siteye Git ve Başvur',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.ormanYesili,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Takibe ekle
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () => _basvuruTakipEkle(context),
                      icon: const Icon(Icons.playlist_add_rounded),
                      label: const Text('Başvuruya Başladım'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.ormanYesili,
                        side: const BorderSide(color: AppTheme.acikYesil),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _basvuruTakipEkle(BuildContext context) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Başvuru takibi için giriş yapman gerekiyor.'),
          backgroundColor: AppTheme.hata,
        ),
      );
      return;
    }

    try {
      await SupabaseServisi().analiziKaydet(
        AnalizSonucu(
          metin: '## ${tesvik.isim}\n\n'
              '**Kurum:** ${tesvik.kurum ?? "Belirtilmemiş"}\n\n'
              '**Son Başvuru:** ${tesvik.sonBasvuruTarihi != null ? "${tesvik.sonBasvuruTarihi!.day}/${tesvik.sonBasvuruTarihi!.month}/${tesvik.sonBasvuruTarihi!.year}" : "Belirtilmemiş"}\n\n'
              '**Başvuru Linki:** ${tesvik.basvuruUrl ?? "Yok"}\n\n'
              'Bu teşvik için başvuru süreci başlatıldı.',
          kritikUyariVar: _kalanGun != null && _kalanGun! <= 15,
          analizZamani: DateTime.now(),
        ),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Başvuru takip listesine eklendi!'),
            backgroundColor: AppTheme.ormanYesili,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: AppTheme.hata,
          ),
        );
      }
    }
  }
}

// ── UYUM SONUCU MODELİ ───────────────────────────────────────────

class _UyumSonucu {
  final bool uyumlu;
  final List<String> nedenler;
  final List<String> uyumsuzlar;
  final bool genelProgram;

  const _UyumSonucu({
    required this.uyumlu,
    required this.nedenler,
    required this.uyumsuzlar,
    required this.genelProgram,
  });
}

// ── YARDIMCI WİDGET'LAR ──────────────────────────────────────────

class _ProfilUyumKarti extends StatelessWidget {
  final _UyumSonucu uyum;

  const _ProfilUyumKarti({required this.uyum});

  @override
  Widget build(BuildContext context) {
    final Color arkaRenk = uyum.genelProgram
        ? const Color(0xFFE3F2FD)
        : uyum.uyumlu
            ? AppTheme.yaprakAcik
            : Colors.red.shade50;

    final Color kenarRenk = uyum.genelProgram
        ? const Color(0xFF90CAF9)
        : uyum.uyumlu
            ? AppTheme.acikYesil
            : Colors.red.shade200;

    final Color textRenk = uyum.genelProgram
        ? const Color(0xFF1565C0)
        : uyum.uyumlu
            ? AppTheme.ormanYesili
            : Colors.red.shade700;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: arkaRenk,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kenarRenk),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            uyum.genelProgram
                ? '🌐 Genel Program'
                : uyum.uyumlu
                    ? '🎯 Profilinle Uyumlu'
                    : '⚠️ Profilinle Uyumsuz',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textRenk),
          ),
          const SizedBox(height: 8),
          ...uyum.nedenler.map((n) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Text('✅', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(n,
                            style: TextStyle(
                                fontSize: 12, color: textRenk))),
                  ],
                ),
              )),
          ...uyum.uyumsuzlar.map((n) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Text('❌', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(n,
                            style: TextStyle(
                                fontSize: 12, color: textRenk))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _BilgiKarti extends StatelessWidget {
  final String ikon;
  final String baslik;
  final String deger;
  final String? alt;
  final bool renkli;
  final Color renk;

  const _BilgiKarti({
    required this.ikon,
    required this.baslik,
    required this.deger,
    this.alt,
    this.renkli = false,
    this.renk = AppTheme.ormanYesili,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: renkli ? renk.withOpacity(0.08) : AppTheme.kremBeyaz,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: renkli ? renk.withOpacity(0.4) : Colors.green.shade100,
        ),
      ),
      child: Row(
        children: [
          Text(ikon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(baslik,
                  style: const TextStyle(fontSize: 12, color: AppTheme.gri)),
              Text(deger,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: renkli ? renk : AppTheme.koyu,
                  )),
              if (alt != null)
                Text(alt!,
                    style: TextStyle(
                        fontSize: 12,
                        color: renkli ? renk : AppTheme.gri,
                        fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _EtiketKarti extends StatelessWidget {
  final String baslik;
  final List<String> etiketler;
  final Color renk;
  final Color textRenk;

  const _EtiketKarti({
    required this.baslik,
    required this.etiketler,
    required this.renk,
    required this.textRenk,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.kremBeyaz,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(baslik,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.koyu)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: etiketler
                .map((e) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: renk,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(e,
                          style: TextStyle(
                              color: textRenk,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}