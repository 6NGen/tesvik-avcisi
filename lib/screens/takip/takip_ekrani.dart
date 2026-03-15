// lib/screens/takip/takip_ekrani.dart
// Başvuru takipçisi — durum güncellemeli, timeline görünümlü

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/theme/app_theme.dart';
import '../../models/tesvik_model.dart';
import '../../services/supabase_servisi.dart';

final analizGecmisiProvider =
    FutureProvider<List<AnalizGecmisi>>((ref) async {
  return SupabaseServisi().analizGecmisiniGetir();
});

class TakipEkrani extends ConsumerWidget {
  const TakipEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gecmisAsync = ref.watch(analizGecmisiProvider);

    return Scaffold(
      backgroundColor: AppTheme.cimensoluk,
      appBar: AppBar(
        title: const Text('Başvuru Takipçisi'),
        backgroundColor: AppTheme.ormanYesili,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: Colors.white),
            onPressed: () => ref.invalidate(analizGecmisiProvider),
          ),
        ],
      ),
      body: gecmisAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Hata: $e',
              style: const TextStyle(color: AppTheme.gri)),
        ),
        data: (liste) {
          if (liste.isEmpty) {
            return const _BosGorunum();
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: liste.length,
            itemBuilder: (context, i) => _AnalizKarti(
              analiz: liste[i],
              index: i,
              onSil: () async {
                await SupabaseServisi().analiziSil(liste[i].id);
                ref.invalidate(analizGecmisiProvider);
              },
              onDurumGuncelle: (yeniDurum) async {
                await SupabaseServisi()
                    .basvuruDurumunuGuncelle(liste[i].id, yeniDurum);
                ref.invalidate(analizGecmisiProvider);
              },
            ),
          );
        },
      ),
    );
  }
}

// ── BAŞVURU DURUMU TİMELINE ──────────────────────────────────────

class _AnalizKarti extends StatelessWidget {
  final AnalizGecmisi analiz;
  final int index;
  final VoidCallback onSil;
  final Function(String) onDurumGuncelle;

  const _AnalizKarti({
    required this.analiz,
    required this.index,
    required this.onSil,
    required this.onDurumGuncelle,
  });

  String _tarih(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}  '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + index * 60),
      curve: Curves.easeOut,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
            offset: Offset(0, 16 * (1 - v)), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.kremBeyaz,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── BAŞLIK ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.yaprakAcik,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                        child: Text('📋',
                            style: TextStyle(fontSize: 22))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(analiz.belgeOzeti,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppTheme.koyu)),
                        Text(_tarih(analiz.olusturulma),
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.gri)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded,
                        color: Colors.red.shade300, size: 20),
                    onPressed: () => _silOnayla(context),
                  ),
                ],
              ),
            ),

            // ── BAŞVURU DURUMU TİMELINE ───────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _DurumTimeline(
                mevcutDurum: analiz.basvuruDurumu,
                onDurumSec: onDurumGuncelle,
              ),
            ),

            const SizedBox(height: 12),

            // ── AI SONUCU (genişletilebilir) ──────────────────
            Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                title: const Text('AI Analiz Sonucu',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.gri,
                        fontWeight: FontWeight.w600)),
                children: [
                  Container(
                    constraints:
                        const BoxConstraints(maxHeight: 300),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.cimensoluk,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Markdown(
                      data: analiz.aiSonucu
                          .replaceAll('KRITIK_UYARI', ''),
                      shrinkWrap: true,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: AppTheme.koyu),
                      ),
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

  void _silOnayla(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Kaydı sil?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('"${analiz.belgeOzeti}" silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onSil();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.hata),
            child: const Text('Sil',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── DURUM TİMELINE ───────────────────────────────────────────────

class _DurumTimeline extends StatelessWidget {
  final String mevcutDurum;
  final Function(String) onDurumSec;

  const _DurumTimeline({
    required this.mevcutDurum,
    required this.onDurumSec,
  });

  static const _adimlar = [
    ('hazirlaniyor', '📝', 'Hazırlanıyor'),
    ('gonderildi', '📤', 'Gönderildi'),
    ('sonuclandi', '✅', 'Sonuçlandı'),
  ];

  int get _mevcutIndex => _adimlar
      .indexWhere((a) => a.$1 == mevcutDurum)
      .clamp(0, 2);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cimensoluk,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(_adimlar.length * 2 - 1, (i) {
          // Çizgi
          if (i.isOdd) {
            final adimIndex = i ~/ 2;
            return Expanded(
              child: Container(
                height: 2,
                color: adimIndex < _mevcutIndex
                    ? AppTheme.ormanYesili
                    : AppTheme.griAcik,
              ),
            );
          }

          // Adım
          final adimIndex = i ~/ 2;
          final (deger, emoji, etiket) = _adimlar[adimIndex];
          final tamamlandi = adimIndex <= _mevcutIndex;
          final aktif = adimIndex == _mevcutIndex;

          return GestureDetector(
            onTap: () => onDurumSec(deger),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tamamlandi
                        ? AppTheme.ormanYesili
                        : AppTheme.griAcik,
                    shape: BoxShape.circle,
                    border: aktif
                        ? Border.all(
                            color: AppTheme.bugdayAltini, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: Text(emoji,
                        style: const TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(etiket,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: aktif
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: tamamlandi
                          ? AppTheme.ormanYesili
                          : AppTheme.gri,
                    )),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ── BOŞ GÖRÜNÜM ──────────────────────────────────────────────────

class _BosGorunum extends StatelessWidget {
  const _BosGorunum();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.yaprakAcik,
                shape: BoxShape.circle,
              ),
              child: const Center(
                  child:
                      Text('📭', style: TextStyle(fontSize: 38))),
            ),
            const SizedBox(height: 16),
            const Text('Henüz analiz kaydın yok.',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.koyu)),
            const SizedBox(height: 8),
            const Text(
              'Belge analizi yaptıktan sonra\ngeçmişin burada görünür.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.gri),
            ),
          ],
        ),
      ),
    );
  }
}