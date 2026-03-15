// lib/screens/auth/auth_ekrani.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class AuthEkrani extends ConsumerWidget {
  const AuthEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final notifier = ref.read(authNotifierProvider.notifier);

    // Hata varsa göster
    ref.listen(authNotifierProvider, (_, next) {
      if (next.hata != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.hata!),
          backgroundColor: AppTheme.hata,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ));
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.ormanYesili,
      body: Column(
        children: [
          // ── ÜST: Logo alanı ─────────────────────────────────
          Expanded(
            flex: 3,
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppTheme.bugdayAltini, width: 2.5),
                    ),
                    child: const Center(
                      child: Text('🌾',
                          style: TextStyle(fontSize: 50)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Teşvik Avcısı',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.bugdayAltini.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color:
                              AppTheme.bugdayAltini.withOpacity(0.4)),
                    ),
                    child: const Text(
                      'Çiftçinin hibe asistanı',
                      style: TextStyle(
                        color: AppTheme.bugdayAltini,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Özellik listesi
                  _OzellikSatiri(
                      emoji: '🎯',
                      metin: 'Sana özel hibe eşleştirme'),
                  const SizedBox(height: 10),
                  _OzellikSatiri(
                      emoji: '📋',
                      metin: 'Başvuru sürecini takip et'),
                  const SizedBox(height: 10),
                  _OzellikSatiri(
                      emoji: '⏰',
                      metin: 'Son tarih hatırlatmaları'),
                ],
              ),
            ),
          ),

          // ── ALT: Giriş kartı ────────────────────────────────
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              decoration: const BoxDecoration(
                color: AppTheme.kremBeyaz,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Hemen Başla',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.koyu,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Google hesabınla saniyeler içinde giriş yap.',
                    style:
                        TextStyle(color: AppTheme.gri, fontSize: 14),
                  ),
                  const SizedBox(height: 24),

                  // Google ile giriş butonu
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: authState.yukleniyor
                          ? null
                          : notifier.googleIleGirisYap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.koyu,
                        elevation: 2,
                        side: BorderSide(
                            color: Colors.grey.shade200),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: authState.yukleniyor
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppTheme.ormanYesili,
                              ),
                            )
                          : Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Image.network(
                                  'https://www.google.com/favicon.ico',
                                  width: 24,
                                  height: 24,
                                  errorBuilder: (_, __, ___) =>
                                      const Text('G',
                                          style: TextStyle(
                                              fontSize: 20,
                                              fontWeight:
                                                  FontWeight.w700,
                                              color: Colors.blue)),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Google ile Giriş Yap',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Misafir devam
                  TextButton(
                    onPressed: authState.yukleniyor
                        ? null
                        : () => Navigator.of(context)
                            .pushReplacementNamed('/home'),
                    child: const Text(
                      'Giriş yapmadan devam et →',
                      style: TextStyle(color: AppTheme.gri),
                    ),
                  ),

                  const Spacer(),

                  // Gizlilik notu
                  const Text(
                    'Giriş yaparak kişisel verilerinizin '
                    'hibe eşleştirme amacıyla kullanılmasını kabul edersiniz.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppTheme.gri, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OzellikSatiri extends StatelessWidget {
  final String emoji;
  final String metin;

  const _OzellikSatiri(
      {required this.emoji, required this.metin});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Text(
          metin,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}