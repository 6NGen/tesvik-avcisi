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

  // Ana başlatma metodu — main.dart'tan çağrılır
  Future<void> baslat(BuildContext context) async {
    await _fcm.requestPermission();

    try {
      final token = await _fcm.getToken(vapidKey: AppConstants.fcmVapidKey);
      if (token != null) {
        await _db.tokenKaydet(token);
      }
    } catch (e) {
      debugPrint('FCM Token hatası: $e');
    }

    _fcm.onTokenRefresh.listen(_db.tokenKaydet);

    // Ön planda gelen bildirimler
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

  // Eski kodla uyumluluk için
  Future<void> saveDeviceToken(String token) => _db.tokenKaydet(token);
}