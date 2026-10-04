// lib/widgets/tesvik_karti.dart

import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/tesvik_model.dart';
import '../providers/tesvik_provider.dart';
import '../screens/tesvik/tesvik_detay_ekrani.dart';
import 'ortak.dart';

class TesvikKarti extends StatelessWidget {
  final TesvikSatiri satir;
  final bool soluk; // süresi dolmuş görünümü

  const TesvikKarti({super.key, required this.satir, this.soluk = false});

  TesvikModel get t => satir.tesvik;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final cs = context.cs;
    final e = satir.eslesme;

    final kart = Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => TesvikDetayEkrani(tesvik: t))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (t.kurum != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          t.kurum!.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.4,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    Text(
                      t.isim,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                        fontSize: 15,
                      ),
                    ),
                    if (e != null && e.uygun && e.nedenler.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.check_circle_rounded,
                              size: 14, color: r.basari),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              e.nedenler.length > 1
                                  ? e.nedenler[1]
                                  : e.nedenler.first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12, color: cs.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        SureRozeti(sonTarih: t.sonBasvuruTarihi),
                        if (e != null)
                          e.uygun
                              ? Rozet(
                                  metin: '%${e.yuzde} uyum',
                                  renk: r.basari,
                                  zemin: r.basariZemin,
                                  ikon: Icons.track_changes_rounded,
                                )
                              : Rozet(
                                  metin: 'Sana uygun değil',
                                  renk: r.notr,
                                  zemin: r.notrZemin,
                                  ikon: Icons.block_rounded,
                                ),
                        Rozet(
                          metin: t.tumTurkiye
                              ? 'Tüm Türkiye'
                              : t.uygunIller.length == 1
                                  ? t.uygunIller.first
                                  : '${t.uygunIller.length} il',
                          renk: r.bilgi,
                          zemin: r.bilgiZemin,
                          ikon: Icons.place_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: soluk ? Opacity(opacity: 0.6, child: kart) : kart,
    );
  }
}
