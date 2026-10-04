// lib/main.dart

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/mesaj.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/profil_provider.dart';
import 'screens/kabuk/ana_kabuk.dart';
import 'screens/profil/profil_ekrani.dart';
import 'services/notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env eksik/bozuksa uygulama açılışta çökmemeli; ilgili anahtarlar boş kalır.
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('.env yüklenemedi: $e');
  }

  // Firebase yalnızca push için gerekli; başlatılamazsa uygulama yine açılır.
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase başlatılamadı: $e');
  }

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseKey,
  );

  // Reklam SDK'sı açılışı bekletmesin (banner henüz kullanılmıyor).
  unawaited(MobileAds.instance.initialize().then((_) {}, onError: (_) {}));

  runApp(const ProviderScope(child: TesvikApp()));
}

class TesvikApp extends StatelessWidget {
  const TesvikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Teşvik Avcısı',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      scaffoldMessengerKey: rootMessengerKey,
      home: const UygulamaKapisi(),
    );
  }
}

/// Kök yönlendirici: oturum + profil durumuna göre ekran seçer.
/// Rota yığını temizlenmeden yalnızca bu widget yeniden çizilir; giriş/çıkış
/// sonrası ekranlar Navigator.popUntil(isFirst) ile buraya döner.
class UygulamaKapisi extends ConsumerStatefulWidget {
  const UygulamaKapisi({super.key});

  @override
  ConsumerState<UygulamaKapisi> createState() => _UygulamaKapisiState();
}

class _UygulamaKapisiState extends ConsumerState<UygulamaKapisi> {
  @override
  void initState() {
    super.initState();
    // Tek seferlik (servis içinde de korumalı).
    NotificationService().baslat();
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authProvider);
    final profilState = ref.watch(profilProvider);

    if (authAsync.isLoading && !authAsync.hasValue) {
      return const _AcilisEkrani();
    }
    final user = authAsync.valueOrNull;
    if (user == null) return const AnaKabuk();
    if (profilState.yukleniyor) return const _AcilisEkrani();
    if (profilState.profilYok) return const ProfilEkrani();
    // profil var ya da yüklenemedi (hata) → ana kabuk; hata şeridi orada.
    return const AnaKabuk();
  }
}

class _AcilisEkrani extends StatelessWidget {
  const _AcilisEkrani();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.ormanYesili,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.agriculture_rounded, size: 64, color: Colors.white),
            SizedBox(height: 24),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 3),
            ),
          ],
        ),
      ),
    );
  }
}
