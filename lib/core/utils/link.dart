// lib/core/utils/link.dart

import 'package:url_launcher/url_launcher.dart';
import 'mesaj.dart';

const cksEdevletUrl =
    'https://www.turkiye.gov.tr/tarim-ve-orman-bakanligi-ciftci-kayit-sistemi';
const gizlilikUrl = 'https://6ngen.github.io/tesvik-avcisi/privacy.html';

/// Bağlantıyı harici tarayıcıda açar; açılamazsa kullanıcıya mesaj gösterir
/// (eskiden canLaunchUrl false dönünce buton sessizce hiçbir şey yapmıyordu).
Future<void> linkAc(String? url) async {
  final uri = url == null ? null : Uri.tryParse(url.trim());
  if (uri == null || !uri.hasScheme) {
    mesajGoster('Bağlantı geçersiz.', hata: true);
    return;
  }
  try {
    final acildi = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!acildi) mesajGoster('Bağlantı açılamadı.', hata: true);
  } catch (_) {
    mesajGoster('Bağlantı açılamadı.', hata: true);
  }
}
