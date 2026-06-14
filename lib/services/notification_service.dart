// lib/services/notification_service.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import 'supabase_servisi.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final SupabaseServisi _db = SupabaseServisi();

  String? _sonToken; // en son alınan FCM token'ı

  Future<void> baslat(BuildContext context) async {
    await _fcm.requestPermission();

    try {
      final token = await _fcm.getToken(vapidKey: AppConstants.fcmVapidKey);
      debugPrint('FCM Token: $token');
      if (token != null) {
        _sonToken = token;
        debugPrint('Token kaydediliyor...');
        await _db.tokenKaydet(token);
        debugPrint('Token kaydedildi!');
      } else {
        debugPrint('Token NULL geldi!');
      }
    } catch (e) {
      debugPrint('FCM Token hatası: $e');
    }

    _fcm.onTokenRefresh.listen((t) {
      _sonToken = t;
      _db.tokenKaydet(t);
    });

    FirebaseMessaging.onMessage.listen((message) {
      if (message.notification != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${message.notification!.title}\n${message.notification!.body}'),
            backgroundColor: Colors.green[800],
          ),
        );
      }
    });
  }

  Future<void> saveDeviceToken(String token) => _db.tokenKaydet(token);

  /// Giriş/çıkış sonrası çağrılır: son token'ı geçerli oturumun user_id'siyle
  /// yeniden kaydeder (login → token kullanıcıya bağlanır, logout → null olur).
  Future<void> tokeniKullaniciylaEslestir() async {
    final token = _sonToken;
    if (token != null) await _db.tokenKaydet(token);
  }
}