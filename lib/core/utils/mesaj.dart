// lib/core/utils/mesaj.dart
//
// Uygulama genelinde tek ScaffoldMessenger. Servisler (ör. ön plandaki push
// bildirimi) BuildContext tutmadan mesaj gösterebilir; eski/geçersiz context
// yüzünden mesaj kaybolmaz.

import 'package:flutter/material.dart';

final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

void mesajGoster(
  String metin, {
  bool hata = false,
  String? eylemEtiketi,
  VoidCallback? eylem,
}) {
  final messenger = rootMessengerKey.currentState;
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(metin),
        backgroundColor: hata ? const Color(0xFFC62828) : null,
        action: eylem != null && eylemEtiketi != null
            ? SnackBarAction(label: eylemEtiketi, onPressed: eylem)
            : null,
      ),
    );
}

/// Exception metnindeki "Exception: " önekini temizler.
String hataMetni(Object e) {
  final s = e.toString();
  return s.startsWith('Exception: ') ? s.substring(11) : s;
}
