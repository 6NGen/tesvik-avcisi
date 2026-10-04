// lib/widgets/ortak.dart
//
// Ekranlar arasında paylaşılan küçük bileşenler: rozet, süre rozeti,
// boş/hata/giriş-gerekli görünümleri, bölüm başlığı, bilgi şeridi.

import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/tarih.dart';

// ── ROZET ───────────────────────────────────────────────────

class Rozet extends StatelessWidget {
  final String metin;
  final Color renk;
  final Color zemin;
  final IconData? ikon;

  const Rozet({
    super.key,
    required this.metin,
    required this.renk,
    required this.zemin,
    this.ikon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: zemin,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ikon != null) ...[
            Icon(ikon, size: 13, color: renk),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              metin,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: renk, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Son tarihe göre renklenen rozet.
class SureRozeti extends StatelessWidget {
  final DateTime? sonTarih;
  const SureRozeti({super.key, required this.sonTarih});

  @override
  Widget build(BuildContext context) {
    final (renk, zemin, ikon) = sureRenkleri(context, sureDurumu(sonTarih));
    return Rozet(
      metin: kalanMetni(sonTarih),
      renk: renk,
      zemin: zemin,
      ikon: ikon,
    );
  }
}

(Color, Color, IconData) sureRenkleri(BuildContext context, SureDurumu d) {
  final r = context.renkler;
  return switch (d) {
    SureDurumu.suresiz => (r.bilgi, r.bilgiZemin, Icons.all_inclusive_rounded),
    SureDurumu.normal => (r.basari, r.basariZemin, Icons.event_rounded),
    SureDurumu.yaklasiyor => (r.uyari, r.uyariZemin, Icons.schedule_rounded),
    SureDurumu.acil => (r.uyari, r.uyariZemin, Icons.alarm_rounded),
    SureDurumu.kritik => (r.tehlike, r.tehlikeZemin, Icons.alarm_rounded),
    SureDurumu.doldu => (r.notr, r.notrZemin, Icons.event_busy_rounded),
  };
}

// ── DURUM GÖRÜNÜMLERİ ───────────────────────────────────────

/// Boş liste / hata / giriş gerekli gibi tam alan mesajları.
class DurumGorunumu extends StatelessWidget {
  final IconData ikon;
  final String baslik;
  final String? aciklama;
  final String? butonEtiketi;
  final VoidCallback? onButon;
  final Color? vurgu;

  const DurumGorunumu({
    super.key,
    required this.ikon,
    required this.baslik,
    this.aciklama,
    this.butonEtiketi,
    this.onButon,
    this.vurgu,
  });

  @override
  Widget build(BuildContext context) {
    final renk = vurgu ?? context.cs.primary;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: renk.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(ikon, size: 40, color: renk),
            ),
            const SizedBox(height: 20),
            Text(
              baslik,
              textAlign: TextAlign.center,
              style: context.tt.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (aciklama != null) ...[
              const SizedBox(height: 8),
              Text(
                aciklama!,
                textAlign: TextAlign.center,
                style: context.tt.bodyMedium
                    ?.copyWith(color: context.cs.onSurfaceVariant, height: 1.4),
              ),
            ],
            if (butonEtiketi != null && onButon != null) ...[
              const SizedBox(height: 24),
              FilledButton(onPressed: onButon, child: Text(butonEtiketi!)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── BÖLÜM BAŞLIĞI ───────────────────────────────────────────

class BolumBasligi extends StatelessWidget {
  final String baslik;
  final Widget? sag;
  final EdgeInsetsGeometry padding;

  const BolumBasligi({
    super.key,
    required this.baslik,
    this.sag,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              baslik,
              style: context.tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
          ?sag,
        ],
      ),
    );
  }
}

// ── BİLGİ ŞERİDİ ────────────────────────────────────────────

/// Liste üstünde gösterilen, isteğe bağlı eylemli/kapatılabilir bilgi kartı.
class BilgiSeridi extends StatelessWidget {
  final IconData ikon;
  final String baslik;
  final String? aciklama;
  final Color renk;
  final Color zemin;
  final String? eylemEtiketi;
  final VoidCallback? onEylem;
  final VoidCallback? onKapat;

  const BilgiSeridi({
    super.key,
    required this.ikon,
    required this.baslik,
    required this.renk,
    required this.zemin,
    this.aciklama,
    this.eylemEtiketi,
    this.onEylem,
    this.onKapat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: zemin,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(ikon, color: renk, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(baslik,
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13, color: renk)),
                if (aciklama != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(aciklama!,
                        style: TextStyle(
                            fontSize: 12,
                            color: context.cs.onSurfaceVariant,
                            height: 1.3)),
                  ),
              ],
            ),
          ),
          if (eylemEtiketi != null && onEylem != null)
            TextButton(
              onPressed: onEylem,
              style: TextButton.styleFrom(foregroundColor: renk),
              child: Text(eylemEtiketi!),
            ),
          if (onKapat != null)
            IconButton(
              onPressed: onKapat,
              tooltip: 'Kapat',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded,
                  size: 18, color: context.cs.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

// ── GRADYAN BAŞLIK ARKA PLANI ───────────────────────────────

BoxDecoration baslikGradyani(BuildContext context) => BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          context.renkler.baslikGradyanBas,
          context.renkler.baslikGradyanSon,
        ],
      ),
    );
