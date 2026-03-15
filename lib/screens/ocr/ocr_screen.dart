// lib/screens/ocr/ocr_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/ocr_provider.dart';

class OcrScreen extends ConsumerWidget {
  const OcrScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ocrProvider);
    final notifier = ref.read(ocrProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.cimensoluk,
      appBar: AppBar(
        title: const Text('Belge Analizi'),
        backgroundColor: AppTheme.ormanYesili,
        foregroundColor: Colors.white,
        actions: [
          if (!state.bos)
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: notifier.sifirla,
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: _govde(context, state, notifier),
      ),
    );
  }

  Widget _govde(BuildContext context, OcrState state, OcrNotifier notifier) {

    // YÜKLENİYOR
    if (state.yukleniyor) {
      return Center(
        key: const ValueKey('yukleniyor'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                color: AppTheme.ormanYesili,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            const Text('🧠 Yapay zeka analiz ediyor...',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.ormanYesili)),
            const SizedBox(height: 8),
            if (state.dosyaAdi != null)
              Text(state.dosyaAdi!,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.gri)),
            const SizedBox(height: 4),
            const Text('Bu işlem 15–30 saniye sürebilir.',
                style: TextStyle(fontSize: 12, color: AppTheme.gri)),
          ],
        ),
      );
    }

    // SONUÇ
    if (state.sonuc != null) {
      return Column(
        key: const ValueKey('sonuc'),
        children: [
          if (state.sonuc!.kritikUyariVar)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
              color: AppTheme.hata,
              child: const Row(
                children: [
                  Text('⚠️', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'DİKKAT: Uygun bir teşvikin son başvuru tarihi yaklaşıyor!',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.kremBeyaz,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade100),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Markdown(
                  data: state.sonuc!.temizMetin,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: AppTheme.koyu),
                    h2: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ormanYesili),
                    a: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        decoration: TextDecoration.underline),
                  ),
                  onTapLink: (text, href, title) async {
                    if (href != null) {
                      await launchUrl(Uri.parse(href),
                          mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: ElevatedButton.icon(
              onPressed: notifier.dosyaSecVeAnalizeEt,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Yeni Analiz'),
            ),
          ),
        ],
      );
    }

    // HATA
    if (state.hata != null) {
      return Center(
        key: const ValueKey('hata'),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('😔', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              Text(state.hata!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppTheme.hata, fontSize: 14)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: notifier.dosyaSecVeAnalizeEt,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tekrar Dene'),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(200, 52)),
              ),
            ],
          ),
        ),
      );
    }

    // BOŞ — başlangıç ekranı
    return Center(
      key: const ValueKey('bos'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ana kart
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppTheme.kremBeyaz,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.shade100),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.yaprakAcik,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text('📄',
                          style: TextStyle(fontSize: 38)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Belgenizi Yükleyin',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.koyu,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ÇKS belgesi veya teşvik belgelerinizi\nyükleyin, AI analiz etsin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.gri,
                        height: 1.5),
                  ),
                  const SizedBox(height: 24),

                  // Dosya seç butonu
                  ElevatedButton.icon(
                    onPressed: notifier.dosyaSecVeAnalizeEt,
                    icon: const Icon(Icons.folder_open_rounded),
                    label: const Text('Dosya Seç'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.ormanYesili,
                      minimumSize: const Size(220, 54),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Desteklenen formatlar
                  const Text(
                    'PDF • JPG • PNG',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.gri,
                        letterSpacing: 1),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // İpucu
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.altinAcik,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Text('💡', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'e-Devlet\'ten indirdiğiniz ÇKS PDF belgesini '
                      'doğrudan yükleyebilirsiniz.',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.toprakKahve),
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