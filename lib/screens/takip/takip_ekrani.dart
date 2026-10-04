// lib/screens/takip/takip_ekrani.dart
// Başvuru takibi: takibe alınan teşvikler + belge analizleri, durum güncellemeli.

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/link.dart';
import '../../core/utils/mesaj.dart';
import '../../core/utils/tarih.dart';
import '../../models/tesvik_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/takip_provider.dart';
import '../../widgets/ortak.dart';
import '../kabuk/ana_kabuk.dart';

class TakipEkrani extends ConsumerWidget {
  const TakipEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final girisVar = ref.watch(kullaniciIdProvider) != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Takibim'),
        actions: [
          if (girisVar)
            IconButton(
              tooltip: 'Yenile',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => ref.read(takipProvider.notifier).yenile(),
            ),
        ],
      ),
      body: !girisVar
          ? DurumGorunumu(
              ikon: Icons.fact_check_outlined,
              baslik: 'Başvurularını tek yerden takip et',
              aciklama:
                  'Takibe aldığın teşvikler ve belge analizlerin burada listelenir.',
              butonEtiketi: 'Giriş yap',
              onButon: () => girisEkraniniAc(context),
            )
          : const _TakipListesi(),
    );
  }
}

class _TakipListesi extends ConsumerWidget {
  const _TakipListesi();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(takipProvider);
    final notifier = ref.read(takipProvider.notifier);

    if (async.isLoading && !async.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    if (async.hasError && !async.hasValue) {
      return DurumGorunumu(
        ikon: Icons.wifi_off_rounded,
        baslik: 'Liste yüklenemedi',
        aciklama: 'İnternet bağlantını kontrol edip tekrar dene.',
        vurgu: context.renkler.tehlike,
        butonEtiketi: 'Tekrar dene',
        onButon: notifier.yenile,
      );
    }

    final liste = async.valueOrNull ?? const <AnalizGecmisi>[];
    if (liste.isEmpty) {
      return RefreshIndicator(
        onRefresh: notifier.yenile,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.6,
              child: DurumGorunumu(
                ikon: Icons.bookmark_border_rounded,
                baslik: 'Henüz takip ettiğin bir şey yok',
                aciklama:
                    'Bir teşvikin detayında "Takibe al"a dokun ya da belge analizi yap.',
                butonEtiketi: 'Teşviklere göz at',
                onButon: () => ref.read(anaSekmeProvider.notifier).state =
                    AnaSekme.tesvikler,
              ),
            ),
          ],
        ),
      );
    }

    final sayilar = {
      for (final d in BasvuruDurumu.values)
        d: liste.where((a) => a.basvuruDurumu == d).length,
    };

    return RefreshIndicator(
      onRefresh: notifier.yenile,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: liste.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) return _Ozet(sayilar: sayilar);
          final kayit = liste[i - 1];
          return _TakipKarti(
            key: ValueKey(kayit.id),
            kayit: kayit,
            onDurum: (d) async {
              try {
                await notifier.durumGuncelle(kayit.id, d);
              } catch (e) {
                mesajGoster(hataMetni(e), hata: true);
              }
            },
            onSil: () async {
              try {
                await notifier.sil(kayit.id);
                mesajGoster('Kayıt silindi.');
              } catch (e) {
                mesajGoster(hataMetni(e), hata: true);
              }
            },
          );
        },
      ),
    );
  }
}

class _Ozet extends StatelessWidget {
  final Map<BasvuruDurumu, int> sayilar;
  const _Ozet({required this.sayilar});

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final renkler = {
      BasvuruDurumu.hazirlaniyor: (r.uyari, r.uyariZemin),
      BasvuruDurumu.gonderildi: (r.bilgi, r.bilgiZemin),
      BasvuruDurumu.sonuclandi: (r.basari, r.basariZemin),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          for (final d in BasvuruDurumu.values) ...[
            if (d.index > 0) const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: renkler[d]!.$2,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${sayilar[d]}',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: renkler[d]!.$1)),
                    Text(d.etiket,
                        style: TextStyle(
                            fontSize: 12, color: renkler[d]!.$1)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TakipKarti extends StatelessWidget {
  final AnalizGecmisi kayit;
  final ValueChanged<BasvuruDurumu> onDurum;
  final VoidCallback onSil;

  const _TakipKarti({
    super.key,
    required this.kayit,
    required this.onDurum,
    required this.onSil,
  });

  Future<void> _silOnayla(BuildContext context) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kayıt silinsin mi?'),
        content: Text('"${kayit.belgeOzeti}" takip listenden kaldırılacak.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: context.renkler.tehlike,
                minimumSize: const Size(64, 44)),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (onay == true) onSil();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final belge = kayit.belgeAnaliziMi;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 4, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      belge
                          ? Icons.description_outlined
                          : Icons.savings_outlined,
                      color: cs.onPrimaryContainer,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(kayit.belgeOzeti,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(
                          '${belge ? "Belge analizi" : "Teşvik başvurusu"} · '
                          '${tarihSaat(kayit.olusturulma)}',
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sil',
                    icon: Icon(Icons.delete_outline_rounded,
                        color: cs.onSurfaceVariant),
                    onPressed: () => _silOnayla(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SegmentedButton<BasvuruDurumu>(
                segments: [
                  for (final d in BasvuruDurumu.values)
                    ButtonSegment(value: d, label: Text(d.etiket)),
                ],
                selected: {kayit.basvuruDurumu},
                showSelectedIcon: false,
                onSelectionChanged: (s) => onDurum(s.first),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(
                      TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
            Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                title: Text(belge ? 'Analiz sonucu' : 'Ayrıntılar',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurfaceVariant)),
                children: [
                  MarkdownBody(
                    data: analizMetniTemizle(kayit.aiSonucu),
                    onTapLink: (_, href, _) => linkAc(href),
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                        .copyWith(
                      p: const TextStyle(fontSize: 13, height: 1.5),
                      a: TextStyle(
                          color: context.renkler.bilgi,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
