// lib/screens/home/home_screen.dart
// Eşleşme motoru entegre: il + ürün + tip + miktar filtrelemesi

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../models/tesvik_model.dart';
import '../../models/profil_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profil_provider.dart';
import '../../services/supabase_servisi.dart';
import '../../services/eslesme_servisi.dart';
import '../auth/auth_ekrani.dart';
import '../ayarlar/ayarlar_ekrani.dart';
import '../ocr/ocr_screen.dart';
import '../takip/takip_ekrani.dart';

final tesviklerProvider = StreamProvider<List<TesvikModel>>((ref) {
  return SupabaseServisi().tesviklerStream();
});

const String cksEdevletUrl =
    'https://www.turkiye.gov.tr/tarim-ve-orman-bakanligi-ciftci-kayit-sistemi';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  // Profil varsa eşleşme motoru, yoksa tüm liste
  
  List<TesvikModel> _filtrele(
    List<TesvikModel> hepsi, ProfilModel? profil) {
  List<TesvikModel> liste;

  if (profil == null) {
    liste = List<TesvikModel>.from(hepsi);
  } else {
    final sonuclar = EslesmeServisi.eslestir(
      tesvikler: hepsi,
      profil: profil,
    );
    liste = sonuclar.map((s) => s.tesvik).toList();
  }

  // Tarihe göre sırala: yaklaşan önce, tarihi olmayanlar sona
  liste.sort((a, b) {
    if (a.sonBasvuruTarihi == null) return 1;
    if (b.sonBasvuruTarihi == null) return -1;
    return a.sonBasvuruTarihi!.compareTo(b.sonBasvuruTarihi!);
  });

  return liste;
}

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tesviklerAsync = ref.watch(tesviklerProvider);
    final profil = ref.watch(profilProvider).profil;
    final user = Supabase.instance.client.auth.currentUser;
    final girisYapildi = user != null;
    final adSoyad = user?.userMetadata?['full_name'] ??
        user?.userMetadata?['ad_soyad'] ??
        'Çiftçi';

    return Scaffold(
      backgroundColor: AppTheme.cimensoluk,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            backgroundColor: AppTheme.ormanYesili,
            actions: [
              if (girisYapildi) ...[
                IconButton(
                  icon: const Icon(Icons.history_rounded,
                      color: Colors.white),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const TakipEkrani())),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_rounded,
                      color: Colors.white),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const AyarlarEkrani())),
                ),
              ] else
                IconButton(
                  icon: const Icon(Icons.login_rounded,
                      color: Colors.white),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const AuthEkrani())),
                ),
            ],
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
                    padding:
                        const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Text(
                              profil?.tipEmojileri ?? '🌾',
                              style: const TextStyle(fontSize: 26),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    girisYapildi
                                        ? 'Hoş geldin!'
                                        : 'Teşvik Avcısı',
                                    style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12),
                                  ),
                                  Text(
                                    girisYapildi
                                        ? adSoyad
                                        : 'Türkiye\'nin hibe asistanı',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (profil != null)
                              _IlRozeti(il: profil.il),
                          ],
                        ),
                        const SizedBox(height: 14),
                        tesviklerAsync.when(
                          data: (t) {
                            final f = _filtrele(t, profil);
                            return _IstatistikSatiri(
                              uygunSayisi: f.length,
                              kritikSayisi: f
                                  .where((x) => x.kritikTarihMi)
                                  .length,
                              toplamSayisi: t.length,
                            );
                          },
                          loading: () => const SizedBox(),
                          error: (_, __) => const SizedBox(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (!girisYapildi)
            SliverToBoxAdapter(
              child: _MisafirBanner(
                onGirisYap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const AuthEkrani())),
              ),
            ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _CksKarti(),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _HizliIslemler(girisYapildi: girisYapildi),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Text(
                    profil != null
                        ? 'Sana Uygun Teşvikler'
                        : 'Aktif Teşvikler',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.koyu,
                    ),
                  ),
                  const Spacer(),
                  tesviklerAsync.when(
                    data: (t) => _SayacRozeti(
                        sayi: _filtrele(t, profil).length),
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                  ),
                ],
              ),
            ),
          ),

          tesviklerAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                  child: Text('Hata: $e',
                      style:
                          const TextStyle(color: AppTheme.gri))),
            ),
            data: (tesvikler) {
              final filtreli = _filtrele(tesvikler, profil);
              if (filtreli.isEmpty) {
                return SliverFillRemaining(
                    child: _BosGorunum(profil: profil));
              }
              return SliverPadding(
                padding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _TesvikKarti(
                        tesvik: filtreli[i], index: i),
                    childCount: filtreli.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const OcrScreen())),
        backgroundColor: AppTheme.bugdayAltini,
        foregroundColor: AppTheme.koyu,
        icon: const Icon(Icons.document_scanner_rounded),
        label: const Text('Belge Analiz Et',
            style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 4,
      ),
    );
  }
}

class _MisafirBanner extends StatelessWidget {
  final VoidCallback onGirisYap;
  const _MisafirBanner({required this.onGirisYap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.altinAcik,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppTheme.bugdayAltini.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Text('👤', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kişisel eşleştirme için giriş yap',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppTheme.toprakKahve)),
                Text('Sana özel hibeler ve başvuru takibi için.',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.gri)),
              ],
            ),
          ),
          TextButton(
            onPressed: onGirisYap,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.ormanYesili,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('Giriş Yap →',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _CksKarti extends StatefulWidget {
  @override
  State<_CksKarti> createState() => _CksKartiState();
}

class _CksKartiState extends State<_CksKarti> {
  bool _gizle = false;

  @override
  Widget build(BuildContext context) {
    if (_gizle) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.kremBeyaz,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppTheme.bugdayAltini.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: AppTheme.altinAcik,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Center(
                      child: Text('💡',
                          style: TextStyle(fontSize: 20))),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Daha İyi Eşleşme İçin',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppTheme.koyu)),
                      Text(
                          'ÇKS belgenle analiz yaptırırsan sonuçlar çok daha doğru olur.',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.gri)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _gizle = true),
                  child: const Icon(Icons.close_rounded,
                      size: 18, color: AppTheme.gri),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse(cksEdevletUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Text('🏛️',
                        style: TextStyle(fontSize: 14)),
                    label: const Text('e-Devlet\'ten Al',
                        style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.ormanYesili,
                      side: const BorderSide(
                          color: AppTheme.acikYesil),
                      minimumSize: const Size(0, 40),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const OcrScreen())),
                    icon: const Icon(Icons.upload_rounded, size: 16),
                    label: const Text('Belge Yükle',
                        style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 40)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HizliIslemler extends StatelessWidget {
  final bool girisYapildi;
  const _HizliIslemler({required this.girisYapildi});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _HizliButon(
            emoji: '🔍',
            etiket: 'Belge\nAnaliz',
            renk: AppTheme.ormanYesili,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const OcrScreen())),
          ),
        ),
        const SizedBox(width: 10),
        if (girisYapildi) ...[
          Expanded(
            child: _HizliButon(
              emoji: '📋',
              etiket: 'Başvuru\nTakibi',
              renk: AppTheme.ortaYesil,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const TakipEkrani())),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: _HizliButon(
            emoji: '🏛️',
            etiket: 'e-Devlet\nÇKS',
            renk: AppTheme.toprakKahve,
            onTap: () async {
              final uri = Uri.parse(cksEdevletUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri,
                    mode: LaunchMode.externalApplication);
              }
            },
          ),
        ),
      ],
    );
  }
}

class _HizliButon extends StatelessWidget {
  final String emoji;
  final String etiket;
  final Color renk;
  final VoidCallback onTap;

  const _HizliButon({
    required this.emoji,
    required this.etiket,
    required this.renk,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: renk,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: renk.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 6),
            Text(etiket,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.3)),
          ],
        ),
      ),
    );
  }
}

class _IlRozeti extends StatelessWidget {
  final String il;
  const _IlRozeti({required this.il});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Text('📍 $il',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _IstatistikSatiri extends StatelessWidget {
  final int uygunSayisi;
  final int kritikSayisi;
  final int toplamSayisi;

  const _IstatistikSatiri({
    required this.uygunSayisi,
    required this.kritikSayisi,
    required this.toplamSayisi,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IstatCard(deger: '$uygunSayisi', etiket: 'Sana Uygun', ikon: '🎯'),
        const SizedBox(width: 8),
        _IstatCard(
            deger: '$kritikSayisi',
            etiket: 'Yaklaşan',
            ikon: '⏰',
            vurgulu: kritikSayisi > 0),
        const SizedBox(width: 8),
        _IstatCard(deger: '$toplamSayisi', etiket: 'Toplam', ikon: '📋'),
      ],
    );
  }
}

class _IstatCard extends StatelessWidget {
  final String deger;
  final String etiket;
  final String ikon;
  final bool vurgulu;

  const _IstatCard({
    required this.deger,
    required this.etiket,
    required this.ikon,
    this.vurgulu = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: vurgulu
                ? AppTheme.bugdayAltini
                : Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Text(ikon, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(deger,
                  style: TextStyle(
                      color: vurgulu
                          ? AppTheme.bugdayAltini
                          : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900)),
              Text(etiket,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SayacRozeti extends StatelessWidget {
  final int sayi;
  const _SayacRozeti({required this.sayi});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.yaprakAcik,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$sayi teşvik',
          style: const TextStyle(
              color: AppTheme.ormanYesili,
              fontSize: 12,
              fontWeight: FontWeight.w700)),
    );
  }
}

class _BosGorunum extends StatelessWidget {
  final ProfilModel? profil;
  const _BosGorunum({this.profil});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🌱', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text(
            profil != null
                ? '${profil!.il} için uygun teşvik bulunamadı.'
                : 'Henüz aktif teşvik yok.',
            style: const TextStyle(color: AppTheme.gri, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _TesvikKarti extends StatelessWidget {
  final TesvikModel tesvik;
  final int index;

  const _TesvikKarti({required this.tesvik, required this.index});

  _UyariDurumu _uyariDurumu() {
    if (tesvik.sonBasvuruTarihi == null) return _UyariDurumu.yok;
    final kalan =
        tesvik.sonBasvuruTarihi!.difference(DateTime.now()).inDays;
    if (kalan < 0) return _UyariDurumu.bitti;
    if (kalan <= 3) return _UyariDurumu.kritik;
    if (kalan <= 7) return _UyariDurumu.acil;
    if (kalan <= 15) return _UyariDurumu.uyari;
    return _UyariDurumu.normal;
  }

  @override
  Widget build(BuildContext context) {
    final durum = _uyariDurumu();
    final kalan =
        tesvik.sonBasvuruTarihi?.difference(DateTime.now()).inDays;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + index * 80),
      curve: Curves.easeOut,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
            offset: Offset(0, 20 * (1 - v)), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.kremBeyaz,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: durum.borderRengi),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: tesvik.basvuruUrl != null
              ? () async {
                  final uri = Uri.parse(tesvik.basvuruUrl!);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri,
                        mode: LaunchMode.externalApplication);
                  }
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                      color: durum.ikonArkaRengi,
                      borderRadius: BorderRadius.circular(12)),
                  child: Center(
                      child: Text(durum.emoji,
                          style: const TextStyle(fontSize: 22))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tesvik.isim,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.koyu)),
                      if (tesvik.kurum != null) ...[
                        const SizedBox(height: 3),
                        Text(tesvik.kurum!,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.gri)),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (kalan != null && kalan >= 0)
                            _Etiket(
                              metin: durum == _UyariDurumu.normal
                                  ? 'Son: ${tesvik.sonBasvuruTarihi!.day}/${tesvik.sonBasvuruTarihi!.month}/${tesvik.sonBasvuruTarihi!.year}'
                                  : '$kalan gün kaldı!',
                              renk: durum.etiketArkaRengi,
                              textRenk: durum.etiketTextRengi,
                            ),
                          if (durum == _UyariDurumu.bitti)
                            const _Etiket(
                                metin: 'Süre doldu',
                                renk: Color(0xFFF5F5F5),
                                textRenk: AppTheme.gri),
                          if (tesvik.basvuruUrl != null)
                            const _Etiket(
                                metin: '🔗 Resmi Kaynak',
                                renk: Color(0xFFE3F2FD),
                                textRenk: Color(0xFF1565C0)),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                    tesvik.basvuruUrl != null
                        ? Icons.open_in_new_rounded
                        : Icons.chevron_right_rounded,
                    color: AppTheme.gri,
                    size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _UyariDurumu { yok, normal, uyari, acil, kritik, bitti }

extension _UyariDurumuExt on _UyariDurumu {
  String get emoji {
    switch (this) {
      case _UyariDurumu.kritik: return '🔴';
      case _UyariDurumu.acil: return '🟠';
      case _UyariDurumu.uyari: return '🟡';
      case _UyariDurumu.bitti: return '⭕';
      default: return '💰';
    }
  }

  Color get borderRengi {
    switch (this) {
      case _UyariDurumu.kritik: return Colors.red.shade300;
      case _UyariDurumu.acil: return Colors.orange.shade300;
      case _UyariDurumu.uyari: return Colors.amber.shade300;
      case _UyariDurumu.bitti: return Colors.grey.shade200;
      default: return Colors.green.shade100;
    }
  }

  Color get ikonArkaRengi {
    switch (this) {
      case _UyariDurumu.kritik: return Colors.red.shade50;
      case _UyariDurumu.acil: return Colors.orange.shade50;
      case _UyariDurumu.uyari: return Colors.amber.shade50;
      case _UyariDurumu.bitti: return Colors.grey.shade100;
      default: return AppTheme.yaprakAcik;
    }
  }

  Color get etiketArkaRengi {
    switch (this) {
      case _UyariDurumu.kritik: return Colors.red.shade50;
      case _UyariDurumu.acil: return Colors.orange.shade50;
      case _UyariDurumu.uyari: return Colors.amber.shade50;
      default: return AppTheme.yaprakAcik;
    }
  }

  Color get etiketTextRengi {
    switch (this) {
      case _UyariDurumu.kritik: return Colors.red.shade700;
      case _UyariDurumu.acil: return Colors.orange.shade700;
      case _UyariDurumu.uyari: return Colors.amber.shade700;
      default: return AppTheme.ormanYesili;
    }
  }
}

class _Etiket extends StatelessWidget {
  final String metin;
  final Color renk;
  final Color textRenk;

  const _Etiket({
    required this.metin,
    required this.renk,
    required this.textRenk,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: renk, borderRadius: BorderRadius.circular(6)),
      child: Text(metin,
          style: TextStyle(
              color: textRenk,
              fontSize: 11,
              fontWeight: FontWeight.w700)),
    );
  }
}