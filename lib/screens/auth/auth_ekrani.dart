// lib/screens/auth/auth_ekrani.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class AuthEkrani extends ConsumerStatefulWidget {
  const AuthEkrani({super.key});

  @override
  ConsumerState<AuthEkrani> createState() => _AuthEkraniState();
}

class _AuthEkraniState extends ConsumerState<AuthEkrani>
    with SingleTickerProviderStateMixin {
  bool _girisModunda = true;
  bool _sifreGizli = true;

  final _emailController    = TextEditingController();
  final _sifreController    = TextEditingController();
  final _adSoyadController  = TextEditingController();
  final _formKey            = GlobalKey<FormState>();

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _sifreController.dispose();
    _adSoyadController.dispose();
    super.dispose();
  }

  Future<void> _gonder() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(authNotifierProvider.notifier);

    if (_girisModunda) {
      await notifier.girisYap(
        email: _emailController.text.trim(),
        sifre: _sifreController.text,
      );
    } else {
      await notifier.kayitOl(
        email: _emailController.text.trim(),
        sifre: _sifreController.text,
        adSoyad: _adSoyadController.text.trim(),
      );
    }

    final authState = ref.read(authNotifierProvider);
    if (authState.hasError && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AuthNotifier.hataMesajiCevir(authState.error.toString())),
        backgroundColor: AppTheme.hata,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final yukleniyor = ref.watch(authNotifierProvider).isLoading;

    return Scaffold(
      backgroundColor: AppTheme.ormanYesili,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          children: [
            // ── ÜST: Logo alanı ─────────────────────────────────
            Expanded(
              flex: 2,
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo dairesi
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.bugdayAltini,
                          width: 2.5,
                        ),
                      ),
                      child: const Center(
                        child: Text('🌾', style: TextStyle(fontSize: 44)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Teşvik Avcısı',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.bugdayAltini.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppTheme.bugdayAltini.withOpacity(0.4)),
                      ),
                      child: const Text(
                        'Çiftçinin hibe asistanı',
                        style: TextStyle(
                          color: AppTheme.bugdayAltini,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── ALT: Form kartı ──────────────────────────────────
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                decoration: const BoxDecoration(
                  color: AppTheme.kremBeyaz,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Giriş / Kayıt sekmesi
                        Row(
                          children: [
                            _Sekme(
                              metin: 'Giriş Yap',
                              aktif: _girisModunda,
                              onTap: () => setState(() => _girisModunda = true),
                            ),
                            const SizedBox(width: 20),
                            _Sekme(
                              metin: 'Kayıt Ol',
                              aktif: !_girisModunda,
                              onTap: () =>
                                  setState(() => _girisModunda = false),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Ad soyad (kayıtta)
                        if (!_girisModunda) ...[
                          TextFormField(
                            controller: _adSoyadController,
                            decoration: const InputDecoration(
                              labelText: 'Ad Soyad',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) =>
                                v!.isEmpty ? 'Ad soyad girin' : null,
                          ),
                          const SizedBox(height: 14),
                        ],

                        // E-posta
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'E-posta',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (v) {
                            if (v!.isEmpty) return 'E-posta girin';
                            if (!v.contains('@')) return 'Geçersiz e-posta';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Şifre
                        TextFormField(
                          controller: _sifreController,
                          obscureText: _sifreGizli,
                          decoration: InputDecoration(
                            labelText: 'Şifre',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_sifreGizli
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () => setState(
                                  () => _sifreGizli = !_sifreGizli),
                            ),
                          ),
                          validator: (v) {
                            if (v!.isEmpty) return 'Şifre girin';
                            if (v.length < 6) return 'En az 6 karakter';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Ana buton
                        SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: yukleniyor ? null : _gonder,
                            child: yukleniyor
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2.5),
                                  )
                                : Text(
                                    _girisModunda ? 'Giriş Yap' : 'Kayıt Ol'),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Misafir devam
                        TextButton(
                          onPressed: yukleniyor
                              ? null
                              : () => Navigator.of(context)
                                  .pushReplacementNamed('/home'),
                          child: const Text(
                            'Giriş yapmadan devam et →',
                            style: TextStyle(color: AppTheme.gri),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sekme extends StatelessWidget {
  final String metin;
  final bool aktif;
  final VoidCallback onTap;

  const _Sekme(
      {required this.metin, required this.aktif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metin,
            style: TextStyle(
              fontSize: 17,
              fontWeight: aktif ? FontWeight.w800 : FontWeight.w400,
              color: aktif ? AppTheme.ormanYesili : AppTheme.gri,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 3,
            width: aktif ? 56 : 0,
            decoration: BoxDecoration(
              color: AppTheme.bugdayAltini,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}