// lib/screens/ayarlar/ayarlar_ekrani.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profil_provider.dart';
import '../profil/profil_ekrani.dart';

class AyarlarEkrani extends ConsumerWidget {
  const AyarlarEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profil = ref.watch(profilProvider).profil;
    final user = Supabase.instance.client.auth.currentUser;
    final adSoyad = user?.userMetadata?['full_name'] ?? 'Kullanıcı';
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: AppTheme.cimensoluk,
      appBar: AppBar(
        title: const Text('Ayarlar'),
        backgroundColor: AppTheme.ormanYesili,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          // ── KULLANICI BİLGİSİ ──────────────────────────────
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.kremBeyaz,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade100),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.yaprakAcik,
                  child: Text(
                    profil?.tipEmojileri ?? '🌾',
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(adSoyad,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppTheme.koyu,
                          )),
                      if (email.isNotEmpty)
                        Text(email,
                            style: const TextStyle(
                                color: AppTheme.gri, fontSize: 13)),
                      if (profil != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '📍 ${profil.il} • ${profil.ureticiTipleri.map((t) => t.etiket).join(" + ")}',
                          style: const TextStyle(
                              color: AppTheme.ormanYesili,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── PROFİL ────────────────────────────────────────────
          _BolumBasligi(baslik: 'Profilim'),

          _AyarKarti(
            items: [
              _AyarItem(
                icon: Icons.person_outline_rounded,
                baslik: 'Profili Düzenle',
                aciklama: profil != null
                    ? '${profil.il} • ${profil.urunler.take(2).join(", ")}'
                    : 'Henüz profil oluşturulmadı',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const ProfilEkrani(duzenlemeModu: true),
                  ),
                ),
              ),
            ],
          ),

          // ── BİLDİRİMLER ──────────────────────────────────────
          _BolumBasligi(baslik: 'Bildirimler'),

          _AyarKarti(
            items: [
              _AyarItem(
                icon: Icons.notifications_outlined,
                baslik: 'Son Tarih Hatırlatmaları',
                aciklama: 'Hibe son başvuru tarihlerinden önce bildir',
                trailing: Switch(
                  value: true,
                  onChanged: (_) {},
                  activeColor: AppTheme.ormanYesili,
                ),
              ),
              _AyarItem(
                icon: Icons.new_releases_outlined,
                baslik: 'Yeni Hibe Bildirimleri',
                aciklama: 'Sana uygun yeni hibe açıldığında bildir',
                trailing: Switch(
                  value: true,
                  onChanged: (_) {},
                  activeColor: AppTheme.ormanYesili,
                ),
              ),
            ],
          ),

          // ── UYGULAMA ─────────────────────────────────────────
          _BolumBasligi(baslik: 'Uygulama'),

          _AyarKarti(
            items: [
              _AyarItem(
                icon: Icons.info_outline_rounded,
                baslik: 'Hakkında',
                aciklama: 'Teşvik Avcısı v1.0',
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'Teşvik Avcısı',
                  applicationVersion: '1.0.0',
                  applicationIcon: const Text('🌾',
                      style: TextStyle(fontSize: 32)),
                  children: const [
                    Text(
                        'Türk çiftçilerinin hibe ve teşviklere '
                        'kolayca ulaşması için geliştirilmiştir.'),
                  ],
                ),
              ),
            ],
          ),

          // ── ÇIKIŞ ────────────────────────────────────────────
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: () async {
                final onay = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    title: const Text('Çıkış Yap'),
                    content: const Text(
                        'Hesabından çıkmak istediğine emin misin?'),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(context, false),
                        child: const Text('İptal'),
                      ),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.hata),
                        child: const Text('Çıkış Yap',
                            style:
                                TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );

                if (onay == true && context.mounted) {
                  await ref
                      .read(authNotifierProvider.notifier)
                      .cikisYap();
                  if (context.mounted) {
                    Navigator.of(context)
                        .pushNamedAndRemoveUntil(
                            '/', (route) => false);
                  }
                }
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Çıkış Yap'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.hata,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── YARDIMCI WİDGET'LAR ──────────────────────────────────────────

class _BolumBasligi extends StatelessWidget {
  final String baslik;
  const _BolumBasligi({required this.baslik});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(baslik,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.gri,
            letterSpacing: 0.5,
          )),
    );
  }
}

class _AyarKarti extends StatelessWidget {
  final List<_AyarItem> items;
  const _AyarKarti({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.kremBeyaz,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Column(
            children: [
              if (i > 0)
                const Divider(
                    height: 1,
                    indent: 56,
                    color: Color(0xFFF0F0F0)),
              _AyarSatiri(item: item),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _AyarItem {
  final IconData icon;
  final String baslik;
  final String aciklama;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _AyarItem({
    required this.icon,
    required this.baslik,
    required this.aciklama,
    this.onTap,
    this.trailing,
  });
}

class _AyarSatiri extends StatelessWidget {
  final _AyarItem item;
  const _AyarSatiri({required this.item});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: item.onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppTheme.yaprakAcik,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(item.icon,
            color: AppTheme.ormanYesili, size: 20),
      ),
      title: Text(item.baslik,
          style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppTheme.koyu)),
      subtitle: Text(item.aciklama,
          style: const TextStyle(
              fontSize: 12, color: AppTheme.gri)),
      trailing: item.trailing ??
          (item.onTap != null
              ? const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.gri)
              : null),
    );
  }
}