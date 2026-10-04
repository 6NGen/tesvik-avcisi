// lib/core/utils/tarih.dart
//
// Son başvuru tarihi hesapları. Gün farkı saatten bağımsız, takvim günü
// üzerinden hesaplanır (UTC tarihleriyle — yaz saati kaymasından etkilenmez).
// Böylece son gün "0 gün kaldı / Bugün son gün" olur, "Süre doldu" değil.

enum SureDurumu {
  suresiz, // son tarih yok (sürekli program)
  normal, // 15 günden fazla
  yaklasiyor, // 8–15 gün
  acil, // 4–7 gün
  kritik, // 0–3 gün
  doldu; // geçti

  bool get aktif => this != doldu;
  bool get yaklasan => this == yaklasiyor || this == acil || this == kritik;
}

DateTime _gun(DateTime t) => DateTime.utc(t.year, t.month, t.day);

/// Bugünden son tarihe kalan takvim günü. Son tarih bugünse 0, geçtiyse negatif.
int? kalanGun(DateTime? sonTarih, {DateTime? simdi}) {
  if (sonTarih == null) return null;
  final yerel = sonTarih.isUtc ? sonTarih.toLocal() : sonTarih;
  return _gun(yerel).difference(_gun(simdi ?? DateTime.now())).inDays;
}

SureDurumu sureDurumu(DateTime? sonTarih, {DateTime? simdi}) {
  final k = kalanGun(sonTarih, simdi: simdi);
  if (k == null) return SureDurumu.suresiz;
  if (k < 0) return SureDurumu.doldu;
  if (k <= 3) return SureDurumu.kritik;
  if (k <= 7) return SureDurumu.acil;
  if (k <= 15) return SureDurumu.yaklasiyor;
  return SureDurumu.normal;
}

/// "Bugün son gün", "Yarın son gün", "5 gün kaldı", "Süre doldu", "Süresiz".
String kalanMetni(DateTime? sonTarih, {DateTime? simdi}) {
  final k = kalanGun(sonTarih, simdi: simdi);
  if (k == null) return 'Süresiz';
  if (k < 0) return 'Süre doldu';
  if (k == 0) return 'Bugün son gün';
  if (k == 1) return 'Yarın son gün';
  return '$k gün kaldı';
}

const _aylar = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];

/// 4 Ekim 2026
String tarihUzun(DateTime t) {
  final y = t.isUtc ? t.toLocal() : t;
  return '${y.day} ${_aylar[y.month - 1]} ${y.year}';
}

/// 04.10.2026 14:05
String tarihSaat(DateTime t) {
  final y = t.isUtc ? t.toLocal() : t;
  String iki(int n) => n.toString().padLeft(2, '0');
  return '${iki(y.day)}.${iki(y.month)}.${y.year} ${iki(y.hour)}:${iki(y.minute)}';
}
