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
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
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
      routes: {
        '/home': (context) => const HomeScreen(),
        '/auth': (context) => const AuthEkrani(),
        '/profil': (context) => const ProfilEkrani(),
      },
      home: const _AuthRouter(),
    );
  }
}

// Giriş → Profil var mı? → HomeScreen
class _AuthRouter extends ConsumerStatefulWidget {
  const _AuthRouter();

  @override
  ConsumerState<_AuthRouter> createState() => _AuthRouterState();
}

class _AuthRouterState extends ConsumerState<_AuthRouter> {
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
    final profilAsync = ref.watch(profilProvider);

    return authAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const AuthEkrani(),
      data: (user) {
        // Giriş yapılmamış → Auth ekranı
        if (user == null) return const AuthEkrani();

        // Profil yükleniyor → Bekle
        if (profilAsync.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Profil yok → Profil tamamlama
        if (profilAsync.value == null) return const ProfilEkrani();

        // Her şey tamam → Ana ekran
        return const HomeScreen();
      },
    );
  }
}