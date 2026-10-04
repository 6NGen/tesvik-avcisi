// lib/screens/profil/profil_ekrani.dart
// 4 adımlı profil sihirbazı: üretim tipi → il → ürünler → miktar.
// İlk kurulumda kök ekran olarak, düzenlemede ayrı sayfa olarak açılır.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/mesaj.dart';
import '../../core/utils/metin.dart';
import '../../models/profil_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profil_provider.dart';

class ProfilEkrani extends ConsumerStatefulWidget {
  final bool duzenlemeModu; // true = mevcut profili düzenle
  const ProfilEkrani({super.key, this.duzenlemeModu = false});

  @override
  ConsumerState<ProfilEkrani> createState() => _ProfilEkraniState();
}

class _ProfilEkraniState extends ConsumerState<ProfilEkrani> {
  static const _adimSayisi = 4;

  int _adim = 0;
  final List<UreticiTipi> _tipler = [];
  String? _il;
  final List<String> _urunler = [];
  final _dekar = TextEditingController();
  final _kovan = TextEditingController();
  final _hayvan = TextEditingController();
  final _ilArama = TextEditingController();
  bool _kaydediliyor = false;

  @override
  void initState() {
    super.initState();
    final p = ref.read(profilProvider).profil;
    if (widget.duzenlemeModu && p != null) {
      _tipler.addAll(p.ureticiTipleri);
      _il = ilDogrula(p.il);
      _urunler.addAll(p.urunler);
      if (p.dekar != null) _dekar.text = p.dekar!.round().toString();
      if (p.kovanSayisi != null) _kovan.text = '${p.kovanSayisi}';
      if (p.hayvanSayisi != null) _hayvan.text = '${p.hayvanSayisi}';
    }
  }

  @override
  void dispose() {
    _dekar.dispose();
    _kovan.dispose();
    _hayvan.dispose();
    _ilArama.dispose();
    super.dispose();
  }

  bool get _ileriAktif => switch (_adim) {
        0 => _tipler.isNotEmpty,
        1 => _il != null,
        2 => _urunler.isNotEmpty,
        _ => true,
      };

  /// Seçili tiplerin ürünleri + listede olmayan (belgeden/elle eklenen) ürünler.
  List<String> get _secenekUrunler {
    final liste = <String>[
      for (final t in _tipler) ...?tipUrunleri[t],
    ];
    for (final u in _urunler) {
      if (!liste.contains(u)) liste.add(u);
    }
    return liste.toSet().toList();
  }

  void _tipDegistir(UreticiTipi tip) {
    setState(() {
      if (_tipler.remove(tip)) {
        // Yalnızca başka seçili tipe ait olmayan ürünleri kaldır.
        final kalanTipUrunleri = {
          for (final t in _tipler) ...?tipUrunleri[t],
        };
        _urunler.removeWhere((u) =>
            (tipUrunleri[tip] ?? const []).contains(u) &&
            !kalanTipUrunleri.contains(u));
      } else {
        _tipler.add(tip);
      }
    });
  }

  Future<void> _urunEkleDiyalogu() async {
    final c = TextEditingController();
    final yeni = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ürün ekle'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Örn. Nohut'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
    c.dispose();
    final ad = yeni?.trim() ?? '';
    if (ad.isEmpty) return;
    final varMi = _urunler.any((u) => turkceAnahtar(u) == turkceAnahtar(ad));
    if (!varMi) setState(() => _urunler.add(ad));
  }

  Future<void> _kaydet() async {
    final userId = ref.read(kullaniciIdProvider);
    if (userId == null || _il == null) return;
    setState(() => _kaydediliyor = true);

    final profil = ProfilModel(
      userId: userId,
      ureticiTipleri: List.of(_tipler),
      il: _il!,
      urunler: List.of(_urunler),
      dekar: _tipler.contains(UreticiTipi.ciftci) ||
              _tipler.contains(UreticiTipi.organik)
          ? double.tryParse(_dekar.text)
          : null,
      kovanSayisi:
          _tipler.contains(UreticiTipi.arici) ? int.tryParse(_kovan.text) : null,
      hayvanSayisi: _tipler.contains(UreticiTipi.hayvancilik)
          ? int.tryParse(_hayvan.text)
          : null,
    );

    final basarili =
        await ref.read(profilProvider.notifier).profilKaydet(profil);
    if (!mounted) return;
    setState(() => _kaydediliyor = false);

    if (!basarili) {
      mesajGoster('Profil kaydedilemedi. İnternet bağlantını kontrol et.',
          hata: true);
      return;
    }
    if (widget.duzenlemeModu) {
      Navigator.of(context).pop();
      mesajGoster('Profilin güncellendi.');
    }
    // İlk kurulumda kök yönlendirici profil var olunca ana ekrana geçer.
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.duzenlemeModu ? 'Profilimi düzenle' : 'Profilini oluştur'),
        automaticallyImplyLeading: widget.duzenlemeModu,
        actions: [
          if (!widget.duzenlemeModu)
            TextButton(
              onPressed: () =>
                  ref.read(authNotifierProvider.notifier).cikisYap(),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Çıkış'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: (_adim + 1) / _adimSayisi,
              minHeight: 4,
              backgroundColor: cs.surfaceContainer,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Adım ${_adim + 1} / $_adimSayisi',
                      style: TextStyle(
                          color: cs.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(_baslik,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(_aciklama,
                      style:
                          TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: KeyedSubtree(key: ValueKey(_adim), child: _icerik()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  if (_adim > 0) ...[
                    OutlinedButton(
                      onPressed: _kaydediliyor
                          ? null
                          : () => setState(() => _adim--),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(56, 52)),
                      child: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: !_ileriAktif || _kaydediliyor
                          ? null
                          : () {
                              FocusScope.of(context).unfocus();
                              if (_adim < _adimSayisi - 1) {
                                setState(() => _adim++);
                              } else {
                                _kaydet();
                              }
                            },
                      child: _kaydediliyor
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.5))
                          : Text(_adim < _adimSayisi - 1
                              ? 'Devam et'
                              : widget.duzenlemeModu
                                  ? 'Kaydet'
                                  : 'Tamamla'),
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

  String get _baslik => const [
        'Ne üretiyorsun?',
        'Hangi ildesin?',
        'Ürünlerin neler?',
        'Üretim büyüklüğün',
      ][_adim];

  String get _aciklama => const [
        'Birden fazla seçebilirsin.',
        'Faaliyet gösterdiğin ili seç.',
        'Ürettiğin ürünleri seç; listede yoksa ekle.',
        'Eşleştirmeyi iyileştirir. İstersen boş bırakabilirsin.',
      ][_adim];

  Widget _icerik() => switch (_adim) {
        0 => _tipSecimi(),
        1 => _ilSecimi(),
        2 => _urunSecimi(),
        _ => _miktarGirisi(),
      };

  // ADIM 1 — Üretim tipi
  Widget _tipSecimi() {
    final cs = context.cs;
    return GridView.count(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.15,
      children: [
        for (final tip in UreticiTipi.values)
          Builder(builder: (context) {
            final secili = _tipler.contains(tip);
            return Material(
              color: secili ? cs.primary : cs.surfaceContainerLowest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                    color: secili ? cs.primary : cs.outlineVariant,
                    width: secili ? 2 : 1),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _tipDegistir(tip),
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(tip.ikon,
                              size: 40,
                              color: secili ? cs.onPrimary : cs.primary),
                          const SizedBox(height: 10),
                          Text(tip.etiket,
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: secili ? cs.onPrimary : cs.onSurface)),
                        ],
                      ),
                    ),
                    if (secili)
                      const Positioned(
                        top: 10,
                        right: 10,
                        child: CircleAvatar(
                          radius: 11,
                          backgroundColor: AppTheme.bugdayAltini,
                          child: Icon(Icons.check_rounded,
                              size: 14, color: Colors.black87),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  // ADIM 2 — İl (aranabilir liste)
  Widget _ilSecimi() {
    final arama = turkceAnahtar(_ilArama.text);
    final iller = turkiyeIlleri
        .where((il) => arama.isEmpty || turkceAnahtar(il).contains(arama))
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _ilArama,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: _il ?? 'İl ara',
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: iller.isEmpty
              ? Center(
                  child: Text('Eşleşen il yok',
                      style: TextStyle(color: context.cs.onSurfaceVariant)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: iller.length,
                  itemBuilder: (_, i) {
                    final il = iller[i];
                    final secili = il == _il;
                    return ListTile(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      selected: secili,
                      selectedTileColor: context.cs.primaryContainer,
                      title: Text(il,
                          style: TextStyle(
                              fontWeight:
                                  secili ? FontWeight.w800 : FontWeight.w500)),
                      trailing: secili
                          ? const Icon(Icons.check_circle_rounded)
                          : null,
                      onTap: () => setState(() => _il = il),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ADIM 3 — Ürünler
  Widget _urunSecimi() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final urun in _secenekUrunler)
            FilterChip(
              label: Text(urun),
              selected: _urunler.contains(urun),
              onSelected: (s) => setState(() {
                s ? _urunler.add(urun) : _urunler.remove(urun);
              }),
            ),
          ActionChip(
            avatar: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Başka ürün ekle'),
            onPressed: _urunEkleDiyalogu,
          ),
        ],
      ),
    );
  }

  // ADIM 4 — Miktar (seçili tiplere göre)
  Widget _miktarGirisi() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        if (_tipler.contains(UreticiTipi.ciftci) ||
            _tipler.contains(UreticiTipi.organik))
          _MiktarAlani(
              controller: _dekar,
              baslik: 'Arazi büyüklüğü',
              birim: 'dekar',
              ikon: Icons.landscape_outlined),
        if (_tipler.contains(UreticiTipi.arici))
          _MiktarAlani(
              controller: _kovan,
              baslik: 'Kovan sayısı',
              birim: 'kovan',
              ikon: Icons.hive_outlined),
        if (_tipler.contains(UreticiTipi.hayvancilik))
          _MiktarAlani(
              controller: _hayvan,
              baslik: 'Hayvan sayısı',
              birim: 'baş',
              ikon: Icons.pets_outlined),
      ],
    );
  }
}

class _MiktarAlani extends StatelessWidget {
  final TextEditingController controller;
  final String baslik;
  final String birim;
  final IconData ikon;

  const _MiktarAlani({
    required this.controller,
    required this.baslik,
    required this.birim,
    required this.ikon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(7),
        ],
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        decoration: InputDecoration(
          labelText: baslik,
          prefixIcon: Icon(ikon),
          suffixText: birim,
          hintText: '0',
        ),
      ),
    );
  }
}
