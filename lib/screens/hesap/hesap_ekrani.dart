// lib/screens/hesap/hesap_ekrani.dart
// Hesap, profil özeti, bildirim tercihleri ve uygulama bilgileri.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/link.dart';
import '../../core/utils/mesaj.dart';
import '../../models/profil_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profil_provider.dart';
import '../../widgets/ortak.dart';
import '../kabuk/ana_kabuk.dart';
import '../profil/profil_ekrani.dart';

class HesapEkrani extends ConsumerWidget {
  const HesapEkrani({super.key});

  Future<void> _cikisYap(BuildContext context, WidgetRef ref) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çıkış yapılsın mı?'),
        content: const Text('Teşvikleri misafir olarak görmeye devam edebilirsin.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text('Çıkış yap'),
          ),
        ],
      ),
    );
    if (onay != true) return;
    await ref.read(authNotifierProvider.notifier).cikisYap();
    ref.read(anaSekmeProvider.notifier).state = AnaSekme.tesvikler;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final profilState = ref.watch(profilProvider);
    final profil = profilState.profil;
    final cikisYukleniyor = ref.watch(authNotifierProvider).yukleniyor;
    final cs = context.cs;

    return Scaffold(
      appBar: AppBar(title: const Text('Hesabım')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // ── KULLANICI ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: user == null
                ? Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.account_circle_outlined,
                              size: 40, color: cs.primary),
                          const SizedBox(height: 12),
                          const Text('Misafir olarak geziyorsun',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(
                            'Giriş yaparak sana özel eşleştirme, başvuru takibi, '
                            'belge analizi ve son tarih hatırlatmalarını aç.',
                            style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () => girisEkraniniAc(context),
                              child: const Text('Google ile giriş yap'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: cs.primaryContainer,
                            child: Text(
                              _basHarf(user.userMetadata?['full_name'] as String? ??
                                  user.email),
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: cs.onPrimaryContainer),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.userMetadata?['full_name'] as String? ??
                                      'Kullanıcı',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800),
                                ),
                                if (user.email != null)
                                  Text(user.email!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: cs.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),

          // ── PROFİL ───────────────────────────────────────────
          if (user != null) ...[
            BolumBasligi(
              baslik: 'Üretici profilim',
              sag: profil == null
                  ? null
                  : TextButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) =>
                                const ProfilEkrani(duzenlemeModu: true)),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Düzenle'),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: profil != null
                  ? _ProfilOzeti(profil: profil)
                  : BilgiSeridi(
                      ikon: Icons.cloud_off_rounded,
                      baslik: 'Profil yüklenemedi',
                      renk: context.renkler.tehlike,
                      zemin: context.renkler.tehlikeZemin,
                      eylemEtiketi: 'Tekrar dene',
                      onEylem: () =>
                          ref.read(profilProvider.notifier).yenile(),
                    ),
            ),

            // ── BİLDİRİMLER ────────────────────────────────────
            const BolumBasligi(baslik: 'Bildirimler'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.alarm_rounded),
                      title: const Text('Son tarih hatırlatmaları'),
                      subtitle:
                          const Text('Uygun hibelerin süresi bitmeden haber ver'),
                      value: profil?.bildirimSonTarih ?? true,
                      onChanged: profil == null
                          ? null
                          : (v) => _tercih(ref, sonTarih: v),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    SwitchListTile(
                      secondary: const Icon(Icons.new_releases_outlined),
                      title: const Text('Yeni hibe bildirimleri'),
                      subtitle:
                          const Text('Sana uygun yeni hibe açıldığında haber ver'),
                      value: profil?.bildirimYeniHibe ?? true,
                      onChanged: profil == null
                          ? null
                          : (v) => _tercih(ref, yeniHibe: v),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── UYGULAMA ─────────────────────────────────────────
          const BolumBasligi(baslik: 'Uygulama'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.account_balance_outlined),
                    title: const Text('e-Devlet ÇKS sayfası'),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: () => linkAc(cksEdevletUrl),
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Gizlilik politikası'),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: () => linkAc(gizlilikUrl),
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: const Text('Hakkında'),
                    onTap: () => showAboutDialog(
                      context: context,
                      applicationName: 'Teşvik Avcısı',
                      applicationVersion: '1.1.0',
                      applicationIcon: Icon(Icons.agriculture_rounded,
                          size: 40, color: cs.primary),
                      children: const [
                        Text('Türk çiftçilerinin hibe ve teşviklere kolayca '
                            'ulaşması için geliştirilmiştir. Teşvik bilgileri '
                            'resmi kaynaklardan otomatik derlenir.'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (user != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: OutlinedButton.icon(
                onPressed:
                    cikisYukleniyor ? null : () => _cikisYap(context, ref),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.renkler.tehlike,
                  side: BorderSide(
                      color: context.renkler.tehlike.withValues(alpha: 0.5)),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Çıkış yap'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _tercih(WidgetRef ref, {bool? sonTarih, bool? yeniHibe}) async {
    final ok = await ref
        .read(profilProvider.notifier)
        .bildirimTercihiAyarla(sonTarih: sonTarih, yeniHibe: yeniHibe);
    if (!ok) mesajGoster('Tercih kaydedilemedi. Tekrar dene.', hata: true);
  }

  static String _basHarf(String? s) {
    final t = s?.trim() ?? '';
    return t.isEmpty ? '?' : t.characters.first.toUpperCase();
  }
}

class _ProfilOzeti extends StatelessWidget {
  final ProfilModel profil;
  const _ProfilOzeti({required this.profil});

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final cs = context.cs;

    Widget satir(IconData ikon, String baslik, Widget deger) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(ikon, size: 20, color: cs.onSurfaceVariant),
              const SizedBox(width: 12),
              SizedBox(
                width: 72,
                child: Text(baslik,
                    style:
                        TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              ),
              Expanded(child: deger),
            ],
          ),
        );

    const degerStil = TextStyle(fontSize: 14, fontWeight: FontWeight.w700);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            satir(
              Icons.category_outlined,
              'Üretim',
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in profil.ureticiTipleri)
                    Rozet(
                        metin: t.etiket,
                        ikon: t.ikon,
                        renk: r.basari,
                        zemin: r.basariZemin),
                ],
              ),
            ),
            satir(Icons.place_outlined, 'İl',
                Text(profil.il.isEmpty ? '—' : profil.il, style: degerStil)),
            satir(
              Icons.grass_rounded,
              'Ürünler',
              Text(profil.urunler.isEmpty ? '—' : profil.urunler.join(', '),
                  style: degerStil),
            ),
            if (profil.miktarOzeti.isNotEmpty)
              satir(Icons.straighten_rounded, 'Miktar',
                  Text(profil.miktarOzeti, style: degerStil)),
          ],
        ),
      ),
    );
  }
}
