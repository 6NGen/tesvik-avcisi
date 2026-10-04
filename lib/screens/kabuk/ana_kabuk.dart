// lib/screens/kabuk/ana_kabuk.dart
//
// Alt menülü ana iskelet: Teşvikler · Takibim · Belge Analizi · Hesabım.
// Sekmeler IndexedStack ile canlı tutulur (kaydırma/filtre durumu kaybolmaz).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_ekrani.dart';
import '../hesap/hesap_ekrani.dart';
import '../ocr/belge_analiz_ekrani.dart';
import '../takip/takip_ekrani.dart';
import '../tesvikler/tesvikler_ekrani.dart';

enum AnaSekme { tesvikler, takip, belge, hesap }

final anaSekmeProvider = StateProvider<AnaSekme>((ref) => AnaSekme.tesvikler);

/// Giriş ekranını açar. Başarılı girişte ekran kendini kapatır.
Future<void> girisEkraniniAc(BuildContext context) => Navigator.of(context)
    .push(MaterialPageRoute(builder: (_) => const AuthEkrani()));

class AnaKabuk extends ConsumerWidget {
  const AnaKabuk({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sekme = ref.watch(anaSekmeProvider);

    return PopScope(
      // Geri tuşu: önce ilk sekmeye dön, sonra uygulamadan çık.
      canPop: sekme == AnaSekme.tesvikler,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ref.read(anaSekmeProvider.notifier).state = AnaSekme.tesvikler;
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: sekme.index,
          children: const [
            TesviklerEkrani(),
            TakipEkrani(),
            BelgeAnalizEkrani(),
            HesapEkrani(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: sekme.index,
          onDestinationSelected: (i) =>
              ref.read(anaSekmeProvider.notifier).state = AnaSekme.values[i],
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.savings_outlined),
              selectedIcon: Icon(Icons.savings_rounded),
              label: 'Teşvikler',
            ),
            NavigationDestination(
              icon: Icon(Icons.fact_check_outlined),
              selectedIcon: Icon(Icons.fact_check_rounded),
              label: 'Takibim',
            ),
            NavigationDestination(
              icon: Icon(Icons.document_scanner_outlined),
              selectedIcon: Icon(Icons.document_scanner_rounded),
              label: 'Belge Analizi',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Hesabım',
            ),
          ],
        ),
      ),
    );
  }
}
