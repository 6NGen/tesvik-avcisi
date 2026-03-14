// lib/screens/takip/takip_ekrani.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/theme/app_theme.dart';
import '../../models/tesvik_model.dart';
import '../../services/supabase_servisi.dart';

final analizGecmisiProvider = FutureProvider<List<AnalizGecmisi>>((ref) async {
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => ref.invalidate(analizGecmisiProvider),
          ),
        ],
      ),
      body: gecmisAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Hata: $e',
                style: const TextStyle(color: AppTheme.gri))),
        data: (liste) {
          if (liste.isEmpty) {
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
                        child: Text('📭', style: TextStyle(fontSize: 38)),
                      ),
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

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: liste.length,
            itemBuilder: (context, index) => _AnalizKarti(
              analiz: liste[index],
              index: index,
              onSil: () async {
                await SupabaseServisi().analiziSil(liste[index].id);
                ref.invalidate(analizGecmisiProvider);
              },
            ),
          );
        },
      ),
    );
  }
}

class _AnalizKarti extends StatelessWidget {
  final AnalizGecmisi analiz;
  final int index;
  final VoidCallback onSil;

  const _AnalizKarti(
      {required this.analiz, required this.index, required this.onSil});

  String _tarih(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + index * 60),
      curve: Curves.easeOut,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.yaprakAcik,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('📋', style: TextStyle(fontSize: 22)),
              ),
            ),
            title: Text(analiz.belgeOzeti,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14)),
            subtitle: Text(_tarih(analiz.olusturulma),
                style:
                    const TextStyle(fontSize: 11, color: AppTheme.gri)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded,
                      color: Colors.red.shade300, size: 20),
                  onPressed: () => _silOnayla(context),
                ),
                const Icon(Icons.expand_more_rounded,
                    color: AppTheme.gri),
              ],
            ),
            children: [
              Container(
                constraints: const BoxConstraints(maxHeight: 380),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.cimensoluk,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Markdown(
                  data: analiz.aiSonucu.replaceAll('KRITIK_UYARI', ''),
                  shrinkWrap: true,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(
                        fontSize: 13, height: 1.5, color: AppTheme.koyu),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _silOnayla(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Kaydı sil?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('"${analiz.belgeOzeti}" silinecek.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onSil();
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.hata),
            child: const Text('Sil',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}