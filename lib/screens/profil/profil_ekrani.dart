// lib/screens/profil/profil_ekrani.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../models/profil_model.dart';
import '../../providers/profil_provider.dart';

class ProfilEkrani extends ConsumerStatefulWidget {
  final bool duzenlemeModu; // true = mevcut profili düzenle
  const ProfilEkrani({super.key, this.duzenlemeModu = false});

  @override
  ConsumerState<ProfilEkrani> createState() => _ProfilEkraniState();
}

class _ProfilEkraniState extends ConsumerState<ProfilEkrani> {
  int _adim = 0;
  final List<UreticiTipi> _tipler = []; // Çoklu tip
  String? _il;
  final List<String> _urunler = [];
  final _dekarController = TextEditingController();
  final _kovanController = TextEditingController();
  final _hayvanController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Düzenleme modunda mevcut profili yükle
    if (widget.duzenlemeModu) {
      final profil = ref.read(profilProvider).profil;
      if (profil != null) {
        _tipler.addAll(profil.ureticiTipleri);
        _il = profil.il;
        _urunler.addAll(profil.urunler);
        if (profil.dekar != null) {
          _dekarController.text = profil.dekar!.toInt().toString();
        }
        if (profil.kovanSayisi != null) {
          _kovanController.text = profil.kovanSayisi.toString();
        }
        if (profil.hayvanSayisi != null) {
          _hayvanController.text = profil.hayvanSayisi.toString();
        }
      }
    }
  }

  @override
  void dispose() {
    _dekarController.dispose();
    _kovanController.dispose();
    _hayvanController.dispose();
    super.dispose();
  }

  bool get _ileriAktif {
    switch (_adim) {
      case 0: return _tipler.isNotEmpty;
      case 1: return _il != null;
      case 2: return _urunler.isNotEmpty;
      case 3: return true;
      default: return false;
    }
  }

  // Seçili tiplere göre tüm ürünleri birleştir
  List<String> get _tumUrunler {
    final liste = <String>{};
    for (final tip in _tipler) {
      liste.addAll(tipUrunleri[tip] ?? []);
    }
    return liste.toList();
  }

  Future<void> _tamamla() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final profil = ProfilModel(
      userId: user.id,
      ureticiTipleri: _tipler,
      il: _il!,
      urunler: _urunler,
      dekar: double.tryParse(_dekarController.text),
      kovanSayisi: int.tryParse(_kovanController.text),
      hayvanSayisi: int.tryParse(_hayvanController.text),
    );

    final basarili =
        await ref.read(profilProvider.notifier).profilKaydet(profil);

    if (mounted) {
      if (basarili) {
        if (widget.duzenlemeModu) {
          Navigator.pop(context); // Ayarlar ekranına geri dön
        } else {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/',
            (route) => false,
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil kaydedilemedi.'),
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
      appBar: widget.duzenlemeModu
          ? AppBar(
              title: const Text('Profilimi Düzenle'),
              backgroundColor: AppTheme.ormanYesili,
              foregroundColor: Colors.white,
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            // İlerleme çubuğu
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  Text('Adım ${_adim + 1}/4',
                      style: const TextStyle(
                          color: AppTheme.gri,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(_adimBasligi(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.koyu,
                      )),
                  const SizedBox(height: 4),
                  Text(_adimAciklamasi(),
                      style: const TextStyle(
                          color: AppTheme.gri, fontSize: 14)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: KeyedSubtree(
                  key: ValueKey(_adim),
                  child: _adimIcerigi(),
                ),
              ),
            ),

            // Alt butonlar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Row(
                children: [
                  if (_adim > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: OutlinedButton(
                        onPressed: () => setState(() => _adim--),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(60, 54),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          side: const BorderSide(color: AppTheme.griAcik),
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            color: AppTheme.gri),
                      ),
                    ),
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
                        _adim < 3
                            ? 'Devam Et'
                            : widget.duzenlemeModu
                                ? 'Kaydet ✓'
                                : 'Tamamla 🎉',
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

  String _adimBasligi() {
    switch (_adim) {
      case 0: return 'Ne üretiyorsunuz?';
      case 1: return 'Hangi ilde?';
      case 2: return 'Ürünleriniz?';
      case 3: return 'Üretim miktarı?';
      default: return '';
    }
  }

  String _adimAciklamasi() {
    switch (_adim) {
      case 0: return 'Birden fazla seçebilirsiniz.';
      case 1: return 'Faaliyet gösterdiğiniz ili seçin.';
      case 2: return 'Ürettiğiniz ürünleri seçin.';
      case 3: return 'Hibe hesaplaması için kullanılır. (Opsiyonel)';
      default: return '';
    }
  }

  Widget _adimIcerigi() {
    switch (_adim) {
      case 0: return _tipSecimi();
      case 1: return _ilSecimi();
      case 2: return _urunSecimi();
      case 3: return _miktarGirisi();
      default: return const SizedBox();
    }
  }

  // ADIM 1 — Çoklu tip seçimi
  Widget _tipSecimi() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Seçim ipucu
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.altinAcik,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Text('💡', style: TextStyle(fontSize: 16)),
                SizedBox(width: 8),
                Text(
                  'Birden fazla üretim yapıyorsanız hepsini seçin.',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.toprakKahve),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: UreticiTipi.values.map((tip) {
              final secili = _tipler.contains(tip);
              return GestureDetector(
                onTap: () => setState(() {
                  if (secili) {
                    _tipler.remove(tip);
                    // Bu tipe ait ürünleri kaldır
                    final tipUrunListesi = tipUrunleri[tip] ?? [];
                    _urunler.removeWhere(
                        (u) => tipUrunListesi.contains(u));
                  } else {
                    _tipler.add(tip);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: secili
                        ? AppTheme.ormanYesili
                        : AppTheme.kremBeyaz,
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
                              color: AppTheme.ormanYesili
                                  .withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : [],
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Text(tip.emoji,
                                style:
                                    const TextStyle(fontSize: 40)),
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
                      // Seçili işareti
                      if (secili)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: AppTheme.bugdayAltini,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
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
            prefixIcon: Icon(Icons.location_on_outlined,
                color: AppTheme.ormanYesili),
          ),
          hint: const Text('İl seçin...'),
          items: turkiyeIlleri
              .map((il) =>
                  DropdownMenuItem(value: il, child: Text(il)))
              .toList(),
          onChanged: (v) => setState(() => _il = v),
        ),
      ),
    );
  }

  // ADIM 3 — Ürün seçimi (tüm seçili tiplerin ürünleri birleşik)
  Widget _urunSecimi() {
    final liste = _tumUrunler;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Seçili tip rozeti
          Wrap(
            spacing: 8,
            children: _tipler
                .map((t) => Chip(
                      label: Text('${t.emoji} ${t.etiket}'),
                      backgroundColor: AppTheme.yaprakAcik,
                      labelStyle: const TextStyle(
                          color: AppTheme.ormanYesili,
                          fontSize: 12),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          Wrap(
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
                  child: Text(urun,
                      style: TextStyle(
                        color: secili
                            ? Colors.white
                            : AppTheme.koyu,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      )),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ADIM 4 — Miktar (seçili tiplere göre dinamik)
  Widget _miktarGirisi() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Çiftçi veya organik → dekar
          if (_tipler.contains(UreticiTipi.ciftci) ||
              _tipler.contains(UreticiTipi.organik)) ...[
            _MiktarAlani(
              controller: _dekarController,
              baslik: '🌾 Arazi Büyüklüğü',
              birim: 'dekar',
              ipucu: 'Tarım arazinizin toplam büyüklüğü',
            ),
            const SizedBox(height: 16),
          ],

          // Arıcı → kovan
          if (_tipler.contains(UreticiTipi.arici)) ...[
            _MiktarAlani(
              controller: _kovanController,
              baslik: '🐝 Kovan Sayısı',
              birim: 'kovan',
              ipucu: 'Aktif kovan adedi',
            ),
            const SizedBox(height: 16),
          ],

          // Hayvancı → hayvan
          if (_tipler.contains(UreticiTipi.hayvancilik)) ...[
            _MiktarAlani(
              controller: _hayvanController,
              baslik: '🐄 Hayvan Sayısı',
              birim: 'hayvan',
              ipucu: 'Toplam büyük ve küçükbaş sayısı',
            ),
            const SizedBox(height: 16),
          ],

          Text(
            'Bu alanlar opsiyoneldir. Boş bırakabilirsiniz.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppTheme.gri.withOpacity(0.6),
                fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// Miktar giriş alanı
class _MiktarAlani extends StatelessWidget {
  final TextEditingController controller;
  final String baslik;
  final String birim;
  final String ipucu;

  const _MiktarAlani({
    required this.controller,
    required this.baslik,
    required this.birim,
    required this.ipucu,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(baslik,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppTheme.koyu)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.kremBeyaz,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.green.shade100),
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly
            ],
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              hintText: '0',
              hintStyle: TextStyle(
                  color: AppTheme.griAcik,
                  fontSize: 24,
                  fontWeight: FontWeight.w800),
              suffixText: birim,
              suffixStyle: const TextStyle(
                color: AppTheme.ormanYesili,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(ipucu,
            style: TextStyle(
                color: AppTheme.gri.withOpacity(0.6),
                fontSize: 11)),
      ],
    );
  }
}