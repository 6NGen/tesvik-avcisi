// lib/screens/profil/profil_ekrani.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../models/profil_model.dart';
import '../../providers/profil_provider.dart';
import '../home/home_screen.dart';

class ProfilEkrani extends ConsumerStatefulWidget {
  const ProfilEkrani({super.key});

  @override
  ConsumerState<ProfilEkrani> createState() => _ProfilEkraniState();
}

class _ProfilEkraniState extends ConsumerState<ProfilEkrani> {
  // Adım sayacı (0–3)
  int _adim = 0;

  // Seçilen değerler
  UreticiTipi? _tip;
  String? _il;
  final List<String> _urunler = [];
  final _miktarController = TextEditingController();

  @override
  void dispose() {
    _miktarController.dispose();
    super.dispose();
  }

  // İleri butonu aktif mi?
  bool get _ileriAktif {
    switch (_adim) {
      case 0: return _tip != null;
      case 1: return _il != null;
      case 2: return _urunler.isNotEmpty;
      case 3: return true; // miktar opsiyonel
      default: return false;
    }
  }

  // Profili kaydet ve ana sayfaya geç
  Future<void> _tamamla() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final profil = ProfilModel(
      userId: user.id,
      ureticiTipi: _tip!,
      il: _il!,
      urunler: _urunler,
      dekarVeyaKovan: double.tryParse(_miktarController.text),
    );

    final basarili =
        await ref.read(profilProvider.notifier).profilKaydet(profil);

    if (mounted) {
      if (basarili) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil kaydedilemedi. Tekrar deneyin.'),
            backgroundColor: AppTheme.hata,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cimensoluk,
      body: SafeArea(
        child: Column(
          children: [
            // ── ÜST BAR ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // İlerleme çubuğu
                  Row(
                    children: List.generate(4, (i) {
                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(right: 4),
                          height: 4,
                          decoration: BoxDecoration(
                            color: i <= _adim
                                ? AppTheme.ormanYesili
                                : AppTheme.griAcik,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Adım ${_adim + 1}/4',
                    style: const TextStyle(
                      color: AppTheme.gri,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _adimBasligi(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.koyu,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _adimAciklamasi(),
                    style: const TextStyle(
                        color: AppTheme.gri, fontSize: 14),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── ADIM İÇERİĞİ ───────────────────────────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.1, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                      parent: anim, curve: Curves.easeOut)),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: KeyedSubtree(
                  key: ValueKey(_adim),
                  child: _adimIcerigi(),
                ),
              ),
            ),

            // ── ALT BUTONLAR ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Row(
                children: [
                  // Geri
                  if (_adim > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: OutlinedButton(
                        onPressed: () => setState(() => _adim--),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(60, 54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: const BorderSide(color: AppTheme.griAcik),
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            color: AppTheme.gri),
                      ),
                    ),

                  // İleri / Tamamla
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _ileriAktif
                          ? () {
                              if (_adim < 3) {
                                setState(() => _adim++);
                              } else {
                                _tamamla();
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        disabledBackgroundColor: AppTheme.griAcik,
                      ),
                      child: Text(
                        _adim < 3 ? 'Devam Et' : 'Tamamla 🎉',
                        style: const TextStyle(fontSize: 16),
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

  // ── ADIM BAŞLIKLARI ─────────────────────────────────────────

  String _adimBasligi() {
    switch (_adim) {
      case 0: return 'Ne üretiyorsunuz?';
      case 1: return 'Hangi ilde?';
      case 2: return 'Ürünleriniz?';
      case 3: return 'Ne kadar?';
      default: return '';
    }
  }

  String _adimAciklamasi() {
    switch (_adim) {
      case 0: return 'Üretim türünüzü seçin.';
      case 1: return 'Faaliyet gösterdiğiniz ili seçin.';
      case 2: return 'Ürettiğiniz ürünleri seçin. Birden fazla seçebilirsiniz.';
      case 3: return _tip == UreticiTipi.arici
          ? 'Kaç kovanınız var? (Opsiyonel)'
          : 'Toplam arazi büyüklüğünüz? (Opsiyonel)';
      default: return '';
    }
  }

  // ── ADIM İÇERİKLERİ ─────────────────────────────────────────

  Widget _adimIcerigi() {
    switch (_adim) {
      case 0: return _tipSecimi();
      case 1: return _ilSecimi();
      case 2: return _urunSecimi();
      case 3: return _miktarGirisi();
      default: return const SizedBox();
    }
  }

  // ADIM 1 — Üretici tipi
  Widget _tipSecimi() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: UreticiTipi.values.map((tip) {
          final secili = _tip == tip;
          return GestureDetector(
            onTap: () => setState(() => _tip = tip),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: secili ? AppTheme.ormanYesili : AppTheme.kremBeyaz,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: secili
                      ? AppTheme.ormanYesili
                      : Colors.green.shade100,
                  width: secili ? 2 : 1,
                ),
                boxShadow: secili
                    ? [
                        BoxShadow(
                          color:
                              AppTheme.ormanYesili.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(tip.emoji,
                      style: const TextStyle(fontSize: 40)),
                  const SizedBox(height: 10),
                  Text(
                    tip.etiket,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: secili
                          ? Colors.white
                          : AppTheme.koyu,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ADIM 2 — İl seçimi
  Widget _ilSecimi() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.kremBeyaz,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.shade100),
        ),
        child: DropdownButtonFormField<String>(
          value: _il,
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            prefixIcon:
                Icon(Icons.location_on_outlined, color: AppTheme.ormanYesili),
          ),
          hint: const Text('İl seçin...'),
          items: turkiyeIlleri
              .map((il) => DropdownMenuItem(value: il, child: Text(il)))
              .toList(),
          onChanged: (v) => setState(() => _il = v),
        ),
      ),
    );
  }

  // ADIM 3 — Ürün seçimi
  Widget _urunSecimi() {
    final liste = _tip != null ? tipUrunleri[_tip!]! : [];
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: liste.map((urun) {
          final secili = _urunler.contains(urun);
          return GestureDetector(
            onTap: () {
              setState(() {
                if (secili) {
                  _urunler.remove(urun);
                } else {
                  _urunler.add(urun);
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: secili
                    ? AppTheme.ormanYesili
                    : AppTheme.kremBeyaz,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: secili
                      ? AppTheme.ormanYesili
                      : Colors.green.shade100,
                ),
              ),
              child: Text(
                urun,
                style: TextStyle(
                  color: secili ? Colors.white : AppTheme.koyu,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ADIM 4 — Miktar girişi
  Widget _miktarGirisi() {
    final ariciMi = _tip == UreticiTipi.arici;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppTheme.kremBeyaz,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade100),
            ),
            child: TextField(
              controller: _miktarController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                  fontSize: 32, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(24),
                hintText: '0',
                hintStyle: TextStyle(
                    color: AppTheme.griAcik,
                    fontSize: 32,
                    fontWeight: FontWeight.w800),
                suffixText: ariciMi ? 'kovan' : 'dekar',
                suffixStyle: const TextStyle(
                  color: AppTheme.ormanYesili,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Atlayabilirler notu
          Text(
            'Boş bırakabilirsiniz — OCR ile otomatik doldurulur.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppTheme.gri.withOpacity(0.7), fontSize: 12),
          ),
        ],
      ),
    );
  }
}