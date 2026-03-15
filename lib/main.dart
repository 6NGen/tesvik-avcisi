// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/profil_provider.dart';
import 'services/notification_service.dart';
import 'screens/auth/auth_ekrani.dart';
import 'screens/home/home_screen.dart';
import 'screens/profil/profil_ekrani.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message) async {
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler);
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseKey,
  );
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
      initialRoute: '/',
      routes: {
        '/': (context) => const _AppRouter(),
        '/home': (context) => const HomeScreen(),
        '/auth': (context) => const AuthEkrani(),
        '/profil': (context) => const ProfilEkrani(),
      },
    );
  }
}

class _AppRouter extends ConsumerStatefulWidget {
  const _AppRouter();

  @override
  ConsumerState<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends ConsumerState<_AppRouter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().baslat(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authProvider);
    final profilState = ref.watch(profilProvider);

    // Auth yükleniyor
    if (authAsync.isLoading) {
      return const _YukleniyorEkran();
    }

    final user = authAsync.value;

    // Giriş yapılmamış → misafir ana ekran
    if (user == null) {
      return const HomeScreen();
    }

    // Giriş yapılmış ama profil yükleniyor
    if (profilState.yukleniyor) {
      return const _YukleniyorEkran();
    }

    // Profil yok → profil tamamlama
    if (profilState.profilYok) {
      return const ProfilEkrani();
    }

    // Her şey tamam → ana ekran
    return const HomeScreen();
  }
}

class _YukleniyorEkran extends StatelessWidget {
  const _YukleniyorEkran();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.ormanYesili,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🌾', style: TextStyle(fontSize: 56)),
            SizedBox(height: 20),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}