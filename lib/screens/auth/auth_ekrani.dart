// lib/screens/auth/auth_ekrani.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/link.dart';
import '../../core/utils/mesaj.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profil_provider.dart';
import '../../widgets/ortak.dart';

class AuthEkrani extends ConsumerWidget {
  const AuthEkrani({super.key});

  Future<void> _girisYap(BuildContext context, WidgetRef ref) async {
    final basarili =
        await ref.read(authNotifierProvider.notifier).googleIleGirisYap();
    if (!basarili || !context.mounted) return;
    // Yeni kullanıcı → kök (profil sihirbazı) görünsün diye yığını temizle;
    // profili olan kullanıcı geldiği ekrana döner.
    if (ref.read(profilProvider).profilYok) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    ref.listen(authNotifierProvider, (_, next) {
      if (next.hata != null) mesajGoster(next.hata!, hata: true);
    });

    return Scaffold(
      backgroundColor: AppTheme.ormanYesili,
      appBar: AppBar(backgroundColor: Colors.transparent),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: baslikGradyani(context),
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, kisit) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: kisit.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppTheme.bugdayAltini, width: 2.5),
                        ),
                        child: const Icon(Icons.agriculture_rounded,
                            size: 48, color: Colors.white),
                      ),
                      const SizedBox(height: 20),
                      const Text('Teşvik Avcısı',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          )),
                      const SizedBox(height: 6),
                      const Text('Çiftçinin hibe asistanı',
                          style: TextStyle(
                            color: AppTheme.bugdayAltini,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          )),
                      const SizedBox(height: 28),
                      const _Ozellik(
                          ikon: Icons.track_changes_rounded,
                          metin: 'Profiline uygun hibeleri otomatik bul'),
                      const _Ozellik(
                          ikon: Icons.fact_check_outlined,
                          metin: 'Başvurularını tek yerden takip et'),
                      const _Ozellik(
                          ikon: Icons.alarm_rounded,
                          metin: 'Son tarihler yaklaşınca hatırlatma al'),
                      const _Ozellik(
                          ikon: Icons.document_scanner_outlined,
                          metin: 'ÇKS belgeni yapay zekâyla analiz et'),
                      const Spacer(),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.fromLTRB(24, 28, 24,
                            20 + MediaQuery.viewPaddingOf(context).bottom),
                        decoration: BoxDecoration(
                          color: context.cs.surface,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(28)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FilledButton.icon(
                              onPressed: authState.yukleniyor
                                  ? null
                                  : () => _girisYap(context, ref),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(64, 56),
                              ),
                              icon: authState.yukleniyor
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.5),
                                    )
                                  : const Text('G',
                                      style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900)),
                              label: const Text('Google ile devam et'),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: authState.yukleniyor
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              child: const Text('Şimdilik misafir olarak devam et'),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => linkAc(gizlilikUrl),
                              child: Text(
                                'Devam ederek tarımsal bilgilerinin hibe '
                                'eşleştirmesi için kullanılmasını kabul edersin. '
                                'Gizlilik politikası',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: context.cs.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Ozellik extends StatelessWidget {
  final IconData ikon;
  final String metin;
  const _Ozellik({required this.ikon, required this.metin});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 6),
      child: Row(
        children: [
          Icon(ikon, color: AppTheme.bugdayAltini, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(metin,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ],
      ),
    );
  }
}
