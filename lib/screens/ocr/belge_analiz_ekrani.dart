// lib/screens/ocr/belge_analiz_ekrani.dart

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/link.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ocr_provider.dart';
import '../../widgets/ortak.dart';
import '../kabuk/ana_kabuk.dart';

class BelgeAnalizEkrani extends ConsumerWidget {
  const BelgeAnalizEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final girisVar = ref.watch(kullaniciIdProvider) != null;
    final state = ref.watch(ocrProvider);
    final notifier = ref.read(ocrProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Belge Analizi'),
        actions: [
          if (girisVar && !state.bos && !state.yukleniyor)
            IconButton(
              tooltip: 'Temizle',
              icon: const Icon(Icons.close_rounded),
              onPressed: notifier.sifirla,
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: !girisVar
            ? DurumGorunumu(
                key: const ValueKey('misafir'),
                ikon: Icons.document_scanner_outlined,
                baslik: 'Belgeni yapay zekâ incelesin',
                aciklama:
                    'ÇKS belgeni yükle; sana uygun teşvikleri bulalım ve profilini otomatik dolduralım. Bunun için giriş yapman gerekiyor.',
                butonEtiketi: 'Giriş yap',
                onButon: () => girisEkraniniAc(context),
              )
            : state.yukleniyor
                ? _Yukleniyor(
                    key: const ValueKey('yukleniyor'), dosyaAdi: state.dosyaAdi)
                : state.sonuc != null
                    ? _Sonuc(key: const ValueKey('sonuc'), state: state)
                    : state.hata != null
                        ? DurumGorunumu(
                            key: const ValueKey('hata'),
                            ikon: Icons.error_outline_rounded,
                            baslik: 'Analiz tamamlanamadı',
                            aciklama: state.hata,
                            vurgu: context.renkler.tehlike,
                            butonEtiketi: 'Başka dosya seç',
                            onButon: notifier.dosyaSecVeAnalizeEt,
                          )
                        : _Baslangic(
                            key: const ValueKey('bos'),
                            onSec: notifier.dosyaSecVeAnalizeEt),
      ),
    );
  }
}

class _Baslangic extends StatelessWidget {
  final VoidCallback onSec;
  const _Baslangic({super.key, required this.onSec});

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final r = context.renkler;

    Widget adim(int no, String metin) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: cs.primaryContainer,
                child: Text('$no',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: cs.onPrimaryContainer)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(metin, style: const TextStyle(fontSize: 13))),
            ],
          ),
        );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: InkWell(
            onTap: onSec,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.upload_file_rounded,
                        size: 36, color: cs.onPrimaryContainer),
                  ),
                  const SizedBox(height: 16),
                  const Text('Belge yükle',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('PDF, JPG veya PNG · en fazla 5 MB',
                      style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onSec,
                    icon: const Icon(Icons.folder_open_rounded),
                    label: const Text('Dosya seç'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const BolumBasligi(
            baslik: 'Nasıl çalışır?', padding: EdgeInsets.fromLTRB(4, 0, 4, 12)),
        adim(1, 'e-Devlet\'ten ÇKS belgeni indir ya da fotoğrafını çek.'),
        adim(2, 'Belgeyi yükle; yapay zekâ tarımsal bilgileri okusun.'),
        adim(3, 'Sana uygun teşvikleri gör, profilin otomatik güncellensin.'),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => linkAc(cksEdevletUrl),
          icon: const Icon(Icons.account_balance_outlined),
          label: const Text('e-Devlet ÇKS sayfasını aç'),
        ),
        const SizedBox(height: 16),
        BilgiSeridi(
          ikon: Icons.lock_outline_rounded,
          baslik: 'Kişisel verilerin saklanmaz',
          aciklama:
              'TC kimlik no, ad ve adres analize dahil edilmez; yalnızca tarımsal bilgiler kullanılır.',
          renk: r.bilgi,
          zemin: r.bilgiZemin,
        ),
      ],
    );
  }
}

class _Yukleniyor extends StatelessWidget {
  final String? dosyaAdi;
  const _Yukleniyor({super.key, this.dosyaAdi});

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 24),
            const Text('Belgen analiz ediliyor…',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            if (dosyaAdi != null) ...[
              const SizedBox(height: 6),
              Text(dosyaAdi!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            ],
            const SizedBox(height: 6),
            Text('Bu işlem 15–30 saniye sürebilir.',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _Sonuc extends ConsumerWidget {
  final OcrState state;
  const _Sonuc({super.key, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.renkler;
    final sonuc = state.sonuc!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (sonuc.kritikUyariVar) ...[
          BilgiSeridi(
            ikon: Icons.alarm_rounded,
            baslik: 'Uygun bir teşvikin son başvuru tarihi yaklaşıyor!',
            renk: r.tehlike,
            zemin: r.tehlikeZemin,
          ),
          const SizedBox(height: 8),
        ],
        if (state.profilGuncellendi) ...[
          BilgiSeridi(
            ikon: Icons.person_pin_rounded,
            baslik: 'Profilin belgeye göre güncellendi',
            aciklama: 'Eşleştirmeler yeni bilgilerle yapılıyor.',
            renk: r.basari,
            zemin: r.basariZemin,
          ),
          const SizedBox(height: 8),
        ],
        if (state.kaydedildi) ...[
          BilgiSeridi(
            ikon: Icons.bookmark_added_outlined,
            baslik: 'Analiz takip listene kaydedildi',
            renk: r.bilgi,
            zemin: r.bilgiZemin,
            eylemEtiketi: 'Takibim',
            onEylem: () =>
                ref.read(anaSekmeProvider.notifier).state = AnaSekme.takip,
          ),
          const SizedBox(height: 8),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: MarkdownBody(
              data: sonuc.temizMetin,
              onTapLink: (_, href, _) => linkAc(href),
              styleSheet:
                  MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: const TextStyle(fontSize: 14, height: 1.6),
                h2: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.cs.primary),
                a: TextStyle(
                    color: r.bilgi,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.underline),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: ref.read(ocrProvider.notifier).dosyaSecVeAnalizeEt,
          icon: const Icon(Icons.upload_file_rounded),
          label: const Text('Yeni belge analiz et'),
        ),
        const SizedBox(height: 8),
        Text(
          'Yapay zekâ hata yapabilir; başvurmadan önce resmi kaynaktan doğrula.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: context.cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
