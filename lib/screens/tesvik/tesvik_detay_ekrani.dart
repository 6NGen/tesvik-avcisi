// lib/screens/tesvik/tesvik_detay_ekrani.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/link.dart';
import '../../core/utils/mesaj.dart';
import '../../core/utils/tarih.dart';
import '../../models/tesvik_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profil_provider.dart';
import '../../providers/takip_provider.dart';
import '../../services/eslesme_servisi.dart';
import '../../widgets/ortak.dart';
import '../kabuk/ana_kabuk.dart';

class TesvikDetayEkrani extends ConsumerStatefulWidget {
  final TesvikModel tesvik;
  const TesvikDetayEkrani({super.key, required this.tesvik});

  @override
  ConsumerState<TesvikDetayEkrani> createState() => _TesvikDetayEkraniState();
}

class _TesvikDetayEkraniState extends ConsumerState<TesvikDetayEkrani> {
  bool _ekleniyor = false;

  TesvikModel get t => widget.tesvik;

  Future<void> _takibeEkle() async {
    if (ref.read(kullaniciIdProvider) == null) {
      await girisEkraniniAc(context);
      return;
    }
    setState(() => _ekleniyor = true);
    try {
      final eklendi =
          await ref.read(takipProvider.notifier).tesvikEkle(t);
      mesajGoster(
        eklendi ? 'Takip listene eklendi.' : 'Bu teşvik zaten takip listende.',
        eylemEtiketi: 'Görüntüle',
        eylem: () {
          ref.read(anaSekmeProvider.notifier).state = AnaSekme.takip;
          if (mounted) {
            Navigator.of(context).popUntil((r) => r.isFirst);
          }
        },
      );
    } catch (e) {
      mesajGoster(hataMetni(e), hata: true);
    } finally {
      if (mounted) setState(() => _ekleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profil = ref.watch(profilProvider).profil;
    final girisVar = ref.watch(kullaniciIdProvider) != null;
    final r = context.renkler;
    final cs = context.cs;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 210,
            title: const Text('Teşvik detayı'),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                decoration: baslikGradyani(context),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (t.kurum != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              t.kurum!.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        Text(
                          t.isim,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
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
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            sliver: SliverList.list(
              children: [
                _SonTarihKarti(tesvik: t),
                const SizedBox(height: 12),
                if (profil != null)
                  _UyumKarti(sonuc: EslesmeServisi.degerlendir(t, profil))
                else
                  BilgiSeridi(
                    ikon: Icons.track_changes_rounded,
                    baslik: girisVar
                        ? 'Uygunluk için profilini tamamla'
                        : 'Sana uygun mu? Giriş yap, hemen görelim',
                    renk: r.bilgi,
                    zemin: r.bilgiZemin,
                    eylemEtiketi: girisVar ? null : 'Giriş',
                    onEylem: girisVar ? null : () => girisEkraniniAc(context),
                  ),
                const SizedBox(height: 12),
                _EtiketBolumu(
                  baslik: 'Kapsadığı iller',
                  ikon: Icons.place_outlined,
                  etiketler: t.uygunIller,
                  bosMetin: 'Tüm Türkiye',
                  renk: r.bilgi,
                  zemin: r.bilgiZemin,
                ),
                _EtiketBolumu(
                  baslik: 'Kapsadığı ürünler',
                  ikon: Icons.grass_rounded,
                  etiketler: t.uygunUrunler,
                  bosMetin: 'Ürün kısıtı belirtilmemiş',
                  renk: r.basari,
                  zemin: r.basariZemin,
                ),
                if (t.etiketler.isNotEmpty)
                  _EtiketBolumu(
                    baslik: 'Kategoriler',
                    ikon: Icons.sell_outlined,
                    etiketler: t.etiketler,
                    renk: cs.onSurfaceVariant,
                    zemin: cs.surfaceContainer,
                  ),
                if (t.minDekar != null && t.minDekar! > 0)
                  _EtiketBolumu(
                    baslik: 'Arazi şartı',
                    ikon: Icons.square_foot_rounded,
                    etiketler: ['En az ${t.minDekar} dekar'],
                    renk: r.uyari,
                    zemin: r.uyariZemin,
                  ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bilgiler resmi kaynaklardan otomatik derlenir. '
                        'Başvurmadan önce şartları resmi sayfadan doğrula.',
                        style:
                            TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            border: Border(top: BorderSide(color: cs.outlineVariant)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _ekleniyor ? null : _takibeEkle,
                  icon: _ekleniyor
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Takibe al'),
                ),
              ),
              if (t.basvuruUrl != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => linkAc(t.basvuruUrl),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Resmi sayfa'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── SON TARİH ───────────────────────────────────────────────

class _SonTarihKarti extends StatelessWidget {
  final TesvikModel tesvik;
  const _SonTarihKarti({required this.tesvik});

  @override
  Widget build(BuildContext context) {
    final tarih = tesvik.sonBasvuruTarihi;
    final (renk, zemin, ikon) = sureRenkleri(context, tesvik.sure);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: zemin,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(ikon, color: renk, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Son başvuru',
                    style: TextStyle(
                        fontSize: 12, color: context.cs.onSurfaceVariant)),
                Text(
                  tarih == null ? 'Süresiz program' : tarihUzun(tarih),
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, color: renk),
                ),
              ],
            ),
          ),
          if (tarih != null)
            Text(kalanMetni(tarih),
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800, color: renk)),
        ],
      ),
    );
  }
}

// ── PROFİL UYUMU ────────────────────────────────────────────

class _UyumKarti extends StatelessWidget {
  final EslesmeSonucu sonuc;
  const _UyumKarti({required this.sonuc});

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final renk = sonuc.uygun ? r.basari : r.tehlike;
    final zemin = sonuc.uygun ? r.basariZemin : r.tehlikeZemin;

    Widget satir(IconData ikon, Color c, String metin) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(ikon, size: 18, color: c),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(metin,
                      style: const TextStyle(fontSize: 13, height: 1.35))),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    sonuc.uygun ? 'Profiline uygun' : 'Profiline uygun değil',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800, color: renk),
                  ),
                ),
                if (sonuc.uygun)
                  Rozet(metin: '%${sonuc.yuzde} uyum', renk: renk, zemin: zemin),
              ],
            ),
            if (sonuc.uygun) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: sonuc.puan,
                  minHeight: 6,
                  color: renk,
                  backgroundColor: zemin,
                ),
              ),
            ],
            for (final n in sonuc.nedenler)
              satir(Icons.check_circle_rounded, r.basari, n),
            for (final n in sonuc.engeller)
              satir(Icons.cancel_rounded, r.tehlike, n),
            for (final n in sonuc.notlar)
              satir(Icons.info_rounded, r.uyari, n),
          ],
        ),
      ),
    );
  }
}

// ── ETİKET BÖLÜMÜ ───────────────────────────────────────────

class _EtiketBolumu extends StatefulWidget {
  final String baslik;
  final IconData ikon;
  final List<String> etiketler;
  final String? bosMetin;
  final Color renk;
  final Color zemin;

  const _EtiketBolumu({
    required this.baslik,
    required this.ikon,
    required this.etiketler,
    required this.renk,
    required this.zemin,
    this.bosMetin,
  });

  @override
  State<_EtiketBolumu> createState() => _EtiketBolumuState();
}

class _EtiketBolumuState extends State<_EtiketBolumu> {
  static const _sinir = 12;
  bool _hepsi = false;

  @override
  Widget build(BuildContext context) {
    final liste = widget.etiketler.isEmpty && widget.bosMetin != null
        ? [widget.bosMetin!]
        : widget.etiketler;
    final fazla = liste.length > _sinir && !_hepsi;
    final gosterilen = fazla ? liste.take(_sinir).toList() : liste;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(widget.ikon, size: 18, color: context.cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(widget.baslik,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in gosterilen)
                    Rozet(metin: e, renk: widget.renk, zemin: widget.zemin),
                  if (fazla)
                    ActionChip(
                      label: Text('+${liste.length - _sinir} daha'),
                      onPressed: () => setState(() => _hepsi = true),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
