// lib/screens/home/home_screen.dart

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
import '../ocr/ocr_screen.dart';
import '../takip/takip_ekrani.dart';

final tesviklerProvider = StreamProvider<List<TesvikModel>>((ref) {
  return SupabaseServisi().tesviklerStream();
});

// e-Devlet ÇKS belgesi alma linki
const String cksEdevletUrl =
    'https://www.turkiye.gov.tr/tarim-ve-orman-bakanligi-ciftci-kayit-sistemi';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  List<TesvikModel> _filtrele(List<TesvikModel> hepsi, ProfilModel? profil) {
    if (profil == null) return hepsi;
    return hepsi.where((t) {
      if (t.uygunIller != null && t.uygunIller!.isNotEmpty) {
        if (!t.uygunIller!.contains(profil.il)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tesviklerAsync = ref.watch(tesviklerProvider);
    final profil = ref.watch(profilProvider).value;
    final user = Supabase.instance.client.auth.currentUser;
    final adSoyad = user?.userMetadata?['ad_soyad'] ?? 'Çiftçi';

    return Scaffold(
      backgroundColor: AppTheme.cimensoluk,
      body: CustomScrollView(
        slivers: [

          // ── APP BAR ───────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            backgroundColor: AppTheme.ormanYesili,
            actions: [
              IconButton(
                icon: const Icon(Icons.history_rounded, color: Colors.white),
                tooltip: 'Başvuru Takipçisi',
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const TakipEkrani())),
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white70),
                tooltip: 'Çıkış',
                onPressed: () =>
                    ref.read(authNotifierProvider.notifier).cikisYap(),
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
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Text(
                              profil?.ureticiTipi.emoji ?? '🌾',
                              style: const TextStyle(fontSize: 26),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Hoş geldin!',
                                      style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12)),
                                  Text(adSoyad,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      )),
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
                              kritikSayisi:
                                  f.where((x) => x.kritikTarihMi).length,
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

          // ── ÇKS BELGE KARTI ───────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _CksBelgeKarti(),
            ),
          ),

          // ── HIZLI İŞLEMLER ────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _HizliIslemler(),
            ),
          ),

          // ── BÖLÜM BAŞLIĞI ─────────────────────────────────────
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
                    data: (t) {
                      final f = _filtrele(t, profil);
                      return _SayacRozeti(sayi: f.length);
                    },
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                  ),
                ],
              ),
            ),
          ),

          // ── TEŞVİK LİSTESİ ────────────────────────────────────
          tesviklerAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                  child: Text('Hata: $e',
                      style: const TextStyle(color: AppTheme.gri))),
            ),
            data: (tesvikler) {
              final filtreli = _filtrele(tesvikler, profil);
              if (filtreli.isEmpty) {
                return SliverFillRemaining(
                  child: _BosTesvikGorunum(profil: profil),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) =>
                        _TesvikKarti(tesvik: filtreli[i], index: i),
                    childCount: filtreli.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),

      // ── FAB ───────────────────────────────────────────────────
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

// ── ÇKS BELGE KARTI ──────────────────────────────────────────────
// Kullanıcıya ÇKS belgesi durumunu gösterir.
// Belgesi yoksa e-Devlet'e yönlendirir.

class _CksBelgeKarti extends StatefulWidget {
  @override
  State<_CksBelgeKarti> createState() => _CksBelgeKartiState();
}

class _CksBelgeKartiState extends State<_CksBelgeKarti> {
  // Kullanıcı "Belgeyi yükledim" derse local olarak işaretle
  bool _belgeYuklendi = false;

  Future<void> _eDevleteGit() async {
    final uri = Uri.parse(cksEdevletUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('e-Devlet açılamadı. Tarayıcınızdan turkiye.gov.tr adresine gidin.'),
            backgroundColor: AppTheme.ormanYesili,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: _belgeYuklendi
            ? AppTheme.yaprakAcik
            : AppTheme.kremBeyaz,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _belgeYuklendi
              ? AppTheme.acikYesil
              : AppTheme.bugdayAltini.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _belgeYuklendi
                        ? AppTheme.acikYesil.withOpacity(0.2)
                        : AppTheme.altinAcik,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      _belgeYuklendi ? '✅' : '📄',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _belgeYuklendi
                            ? 'ÇKS Belgen Hazır'
                            : 'ÇKS Belgen Var Mı?',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: _belgeYuklendi
                              ? AppTheme.ormanYesili
                              : AppTheme.koyu,
                        ),
                      ),
                      Text(
                        _belgeYuklendi
                            ? 'Belge analizine geçebilirsin.'
                            : 'Hibe başvurusu için ÇKS belgesi gereklidir.',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.gri),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (!_belgeYuklendi) ...[
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              const SizedBox(height: 14),

              // e-Devlet butonu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _eDevleteGit,
                  icon: const Text('🏛️',
                      style: TextStyle(fontSize: 16)),
                  label: const Text('e-Devlet\'ten ÇKS Belgemi Al'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.ormanYesili,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Zaten var butonu
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      setState(() => _belgeYuklendi = true),
                  icon: const Icon(Icons.check_circle_outline_rounded,
                      size: 18),
                  label: const Text('Belgeyi Zaten Aldım'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.ormanYesili,
                    side: const BorderSide(color: AppTheme.acikYesil),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
              ),

              const SizedBox(height: 10),
              // Bilgi notu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 13,
                      color: AppTheme.gri.withOpacity(0.7)),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'e-Devlet\'te "Çiftçi Kayıt Sistemi" sayfasından '
                      'ÇKS belgenizi PDF olarak indirebilirsiniz.',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.gri),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 10),
              // Belge yüklendi → analiz et yönlendirmesi
              GestureDetector(
                onTap: () => setState(() => _belgeYuklendi = false),
                child: const Text(
                  'Belge yok, geri al →',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.gri,
                      decoration: TextDecoration.underline),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── HIZLI İŞLEMLER ───────────────────────────────────────────────
// Tek satırda 3 hızlı aksiyon butonu

class _HizliIslemler extends StatelessWidget {
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
        Expanded(
          child: _HizliButon(
            emoji: '📋',
            etiket: 'Başvuru\nTakibi',
            renk: AppTheme.ortaYesil,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TakipEkrani())),
          ),
        ),
        const SizedBox(width: 10),
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
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 6),
            Text(
              etiket,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── YARDIMCI WİDGET'LAR ──────────────────────────────────────────

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
              : Colors.white.withOpacity(0.2),
        ),
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
                    fontWeight: FontWeight.w900,
                  )),
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
            fontWeight: FontWeight.w700,
          )),
    );
  }
}

class _BosTesvikGorunum extends StatelessWidget {
  final ProfilModel? profil;
  const _BosTesvikGorunum({this.profil});

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
                ? '${profil!.il} için aktif teşvik bulunamadı.'
                : 'Henüz aktif teşvik yok.',
            style: const TextStyle(color: AppTheme.gri, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

// ── TEŞVİK KARTI ─────────────────────────────────────────────────

class _TesvikKarti extends StatelessWidget {
  final TesvikModel tesvik;
  final int index;

  const _TesvikKarti({required this.tesvik, required this.index});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + index * 80),
      curve: Curves.easeOut,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child:
            Transform.translate(offset: Offset(0, 20 * (1 - v)), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.kremBeyaz,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: tesvik.kritikTarihMi
                ? Colors.red.shade200
                : Colors.green.shade100,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: tesvik.kritikTarihMi
                      ? Colors.red.shade50
                      : AppTheme.yaprakAcik,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(tesvik.kritikTarihMi ? '⚠️' : '💰',
                      style: const TextStyle(fontSize: 22)),
                ),
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
                          color: AppTheme.koyu,
                        )),
                    if (tesvik.kurum != null) ...[
                      const SizedBox(height: 3),
                      Text(tesvik.kurum!,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.gri)),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (tesvik.kritikTarihMi)
                          _Etiket(
                            metin:
                                '${tesvik.sonBasvuruTarihi!.difference(DateTime.now()).inDays} gün kaldı!',
                            renk: Colors.red.shade50,
                            textRenk: Colors.red.shade700,
                          ),
                        if (tesvik.sonBasvuruTarihi != null &&
                            !tesvik.kritikTarihMi)
                          _Etiket(
                            metin:
                                'Son: ${tesvik.sonBasvuruTarihi!.day}/${tesvik.sonBasvuruTarihi!.month}/${tesvik.sonBasvuruTarihi!.year}',
                            renk: AppTheme.yaprakAcik,
                            textRenk: AppTheme.ormanYesili,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.gri, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _Etiket extends StatelessWidget {
  final String metin;
  final Color renk;
  final Color textRenk;

  const _Etiket(
      {required this.metin, required this.renk, required this.textRenk});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: renk,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(metin,
          style: TextStyle(
              color: textRenk,
              fontSize: 11,
              fontWeight: FontWeight.w700)),
    );
  }
}