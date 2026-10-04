// lib/services/notification_service.dart
//
// Uygulama ömrü boyunca BİR KEZ başlatılır. (Eskiden kök widget her yeniden
// kurulduğunda tekrar başlatılıyor, onMessage/onTokenRefresh dinleyicileri
// birikip aynı bildirim birden çok kez gösteriliyordu.)

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/mesaj.dart';
import 'supabase_servisi.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final SupabaseServisi _db = SupabaseServisi();

  bool _baslatildi = false;
  String? _sonToken;
  final List<StreamSubscription<dynamic>> _abonelikler = [];

  Future<void> baslat() async {
    if (_baslatildi) return;
    _baslatildi = true;
    if (Firebase.apps.isEmpty) {
      debugPrint('Firebase hazır değil; bildirimler devre dışı.');
      return;
    }
    final fcm = FirebaseMessaging.instance;

    try {
      await fcm.requestPermission();
      final token = await fcm.getToken(vapidKey: AppConstants.fcmVapidKey);
      if (token != null) {
        _sonToken = token;
        await _db.tokenKaydet(token);
      }
    } catch (e) {
      debugPrint('FCM token alınamadı: $e');
    }

    _abonelikler
      ..add(fcm.onTokenRefresh.listen((t) {
        _sonToken = t;
        _db.tokenKaydet(t);
      }))
      ..add(FirebaseMessaging.onMessage.listen((message) {
        final n = message.notification;
        if (n == null) return;
        final metin = [n.title, n.body]
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .join('\n');
        if (metin.isNotEmpty) mesajGoster(metin);
      }));
  }

  /// Giriş/çıkış sonrası çağrılır: son token'ı geçerli oturumun user_id'siyle
  /// yeniden kaydeder (login → token kullanıcıya bağlanır, logout → null olur).
  Future<void> tokeniKullaniciylaEslestir() async {
    final token = _sonToken;
    if (token != null) await _db.tokenKaydet(token);
  }
}
