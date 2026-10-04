// lib/screens/tesvikler/tesvikler_ekrani.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/link.dart';
import '../../core/utils/mesaj.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profil_provider.dart';
import '../../providers/tesvik_provider.dart';
import '../../widgets/ortak.dart';
import '../../widgets/tesvik_karti.dart';
import '../kabuk/ana_kabuk.dart';

class TesviklerEkrani extends ConsumerStatefulWidget {
  const TesviklerEkrani({super.key});

  @override
  ConsumerState<TesviklerEkrani> createState() => _TesviklerEkraniState();
}

class _TesviklerEkraniState extends ConsumerState<TesviklerEkrani> {
  final _aramaController = TextEditingController();
  bool _dolanlarAcik = false;

  @override
  void dispose() {
    _aramaController.dispose();
    super.dispose();
  }

  Future<void> _yenile() async {
    ref.invalidate(tesviklerProvider);
    try {
      await ref.read(tesviklerProvider.future);
    } catch (_) {/* hata durumu ekranda gösterilir */}
  }

  void _gizle(TesvikSatiri s) {
    final notifier = ref.read(gizlenenTesviklerProvider.notifier);
    notifier.ekle(s.tesvik.id);
    mesajGoster(
      'Listeden kaldırıldı.',
      eylemEtiketi: 'Geri al',
      eylem: () => notifier.cikar(s.tesvik.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gorunumAsync = ref.watch(tesvikGorunumuProvider);
    final user = ref.watch(authProvider).valueOrNull;
    final profilState = ref.watch(profilProvider);
    final profil = profilState.profil;
    final filtre = ref.watch(tesvikFiltreProvider);
    final kapatilanlar = ref.watch(kapatilanKartlarProvider);
    final gorunum = gorunumAsync.valueOrNull;

    final ad = (user?.userMetadata?['full_name'] as String?)?.split(' ').first;
    final r = context.renkler;

    final filtreler = [
      if (profil != null) TesvikFiltre.uygun,
      TesvikFiltre.tumu,
      TesvikFiltre.yaklasan,
    ];
    final etkinFiltre = filtreler.contains(filtre) ? filtre : TesvikFiltre.tumu;

    return RefreshIndicator(
      onRefresh: _yenile,
      edgeOffset: 120,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── BAŞLIK ──────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 196,
            title: const Text('Teşvik Avcısı'),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                decoration: baslikGradyani(context),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                user == null
                                    ? 'Türkiye\'nin tarım hibe asistanı'
                                    : 'Merhaba${ad != null ? ', $ad' : ''} 👋',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (profil != null && profil.il.isNotEmpty)
                              _BeyazCip(
                                  ikon: Icons.place_rounded, metin: profil.il),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            if (gorunum?.profilVar ?? false) ...[
                              _Istatistik(
                                  deger: gorunum!.uygunSayisi,
                                  etiket: 'Sana uygun'),
                              const SizedBox(width: 8),
                            ],
                            _Istatistik(
                              deger: gorunum?.yaklasanSayisi,
                              etiket: 'Son tarihi yakın',
                              vurgulu: (gorunum?.yaklasanSayisi ?? 0) > 0,
                            ),
                            const SizedBox(width: 8),
                            _Istatistik(
                                deger: gorunum?.toplamAktif,
                                etiket: 'Aktif teşvik'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── ARAMA + FİLTRE ──────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: TextField(
                controller: _aramaController,
                textInputAction: TextInputAction.search,
                onChanged: (v) {
                  ref.read(tesvikAramaProvider.notifier).state = v;
                  setState(() {}); // temizle düğmesinin görünürlüğü
                },
                decoration: InputDecoration(
                  hintText: 'Teşvik, kurum veya ürün ara',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _aramaController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Temizle',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _aramaController.clear();
                            ref.read(tesvikAramaProvider.notifier).state = '';
                            setState(() {});
                          },
                        ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                itemCount: filtreler.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final f = filtreler[i];
                  return ChoiceChip(
                    label: Text(f.etiket),
                    selected: f == etkinFiltre,
                    showCheckmark: false,
                    onSelected: (_) =>
                        ref.read(tesvikFiltreProvider.notifier).state = f,
                  );
                },
              ),
            ),
          ),

          // ── BİLGİ ŞERİTLERİ ─────────────────────────────────
          if (user == null)
            _Serit(
              BilgiSeridi(
                ikon: Icons.person_add_alt_1_rounded,
                baslik: 'Sana özel eşleştirme için giriş yap',
                aciklama: 'Profiline uygun hibeler, başvuru takibi ve hatırlatmalar.',
                renk: r.uyari,
                zemin: r.uyariZemin,
                eylemEtiketi: 'Giriş',
                onEylem: () => girisEkraniniAc(context),
              ),
            )
          else if (profilState.profilHata)
            _Serit(
              BilgiSeridi(
                ikon: Icons.cloud_off_rounded,
                baslik: 'Profilin yüklenemedi',
                aciklama: 'Eşleştirme kapalı. Bağlantını kontrol edip tekrar dene.',
                renk: r.tehlike,
                zemin: r.tehlikeZemin,
                eylemEtiketi: 'Tekrar dene',
                onEylem: () => ref.read(profilProvider.notifier).yenile(),
              ),
            )
          else if (!kapatilanlar.contains('cks'))
            _Serit(
              BilgiSeridi(
                ikon: Icons.lightbulb_outline_rounded,
                baslik: 'Daha doğru eşleşme için ÇKS belgeni yükle',
                aciklama: 'e-Devlet\'ten indirip Belge Analizi\'ne yükleyebilirsin.',
                renk: r.bilgi,
                zemin: r.bilgiZemin,
                eylemEtiketi: 'e-Devlet',
                onEylem: () => linkAc(cksEdevletUrl),
                onKapat: () =>
                    ref.read(kapatilanKartlarProvider.notifier).ekle('cks'),
              ),
            ),

          // ── LİSTE ───────────────────────────────────────────
          ...gorunumAsync.when(
            loading: () => [
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (e, _) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: DurumGorunumu(
                  ikon: Icons.wifi_off_rounded,
                  baslik: 'Teşvikler yüklenemedi',
                  aciklama: 'İnternet bağlantını kontrol edip tekrar dene.',
                  vurgu: r.tehlike,
                  butonEtiketi: 'Tekrar dene',
                  onButon: _yenile,
                ),
              ),
            ],
            data: (g) => _listeSliverlari(context, g, etkinFiltre),
          ),
        ],
      ),
    );
  }

  List<Widget> _listeSliverlari(
      BuildContext context, TesvikGorunumu g, TesvikFiltre filtre) {
    final aramaVar = ref.read(tesvikAramaProvider).trim().isNotEmpty;
    final baslik = switch (filtre) {
      TesvikFiltre.uygun => 'Sana uygun teşvikler',
      TesvikFiltre.tumu => 'Tüm aktif teşvikler',
      TesvikFiltre.yaklasan => 'Son tarihi yaklaşanlar',
    };

    return [
      SliverToBoxAdapter(
        child: BolumBasligi(
          baslik: baslik,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          sag: Text('${g.aktif.length}',
              style: TextStyle(
                  fontWeight: FontWeight.w800, color: context.cs.primary)),
        ),
      ),
      if (g.aktif.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: DurumGorunumu(
              ikon: aramaVar ? Icons.search_off_rounded : Icons.eco_outlined,
              baslik: aramaVar
                  ? 'Aramana uygun teşvik yok'
                  : filtre == TesvikFiltre.uygun
                      ? 'Şu an profiline uygun aktif teşvik yok'
                      : filtre == TesvikFiltre.yaklasan
                          ? 'Son tarihi yaklaşan teşvik yok'
                          : 'Şu an aktif teşvik yok',
              aciklama: filtre == TesvikFiltre.uygun && !aramaVar
                  ? 'Yeni hibe açıldığında bildirim alırsın. Tüm teşviklere de göz atabilirsin.'
                  : null,
              butonEtiketi: filtre == TesvikFiltre.uygun && !aramaVar
                  ? 'Tümünü göster'
                  : null,
              onButon: () => ref.read(tesvikFiltreProvider.notifier).state =
                  TesvikFiltre.tumu,
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: g.aktif.length,
            itemBuilder: (_, i) => TesvikKarti(satir: g.aktif[i]),
          ),
        ),

      // ── SÜRESİ DOLANLAR ───────────────────────────────────
      if (g.dolanlar.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: InkWell(
            onTap: () => setState(() => _dolanlarAcik = !_dolanlarAcik),
            child: BolumBasligi(
              baslik: 'Süresi dolanlar (${g.dolanlar.length})',
              sag: Icon(_dolanlarAcik
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded),
            ),
          ),
        ),
        if (_dolanlarAcik) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text('Listeden kaldırmak için kartı yana kaydır.',
                  style: TextStyle(
                      fontSize: 12, color: context.cs.onSurfaceVariant)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.builder(
              itemCount: g.dolanlar.length,
              itemBuilder: (_, i) {
                final s = g.dolanlar[i];
                return Dismissible(
                  key: ValueKey('dolan-${s.tesvik.id}'),
                  onDismissed: (_) => _gizle(s),
                  background: const _SilArkaPlan(Alignment.centerLeft),
                  secondaryBackground:
                      const _SilArkaPlan(Alignment.centerRight),
                  child: TesvikKarti(satir: s, soluk: true),
                );
              },
            ),
          ),
        ],
      ],
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];
  }
}

class _Serit extends StatelessWidget {
  final Widget child;
  const _Serit(this.child);

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: child,
        ),
      );
}

class _SilArkaPlan extends StatelessWidget {
  final Alignment hiza;
  const _SilArkaPlan(this.hiza);

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: hiza,
        decoration: BoxDecoration(
          color: context.renkler.tehlikeZemin,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.visibility_off_rounded,
            color: context.renkler.tehlike),
      );
}

class _BeyazCip extends StatelessWidget {
  final IconData ikon;
  final String metin;
  const _BeyazCip({required this.ikon, required this.metin});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikon, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(metin,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _Istatistik extends StatelessWidget {
  final int? deger;
  final String etiket;
  final bool vurgulu;

  const _Istatistik(
      {required this.deger, required this.etiket, this.vurgulu = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: vurgulu
                ? AppTheme.bugdayAltini
                : Colors.white.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              deger?.toString() ?? '–',
              style: TextStyle(
                color: vurgulu ? AppTheme.bugdayAltini : Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(etiket,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
