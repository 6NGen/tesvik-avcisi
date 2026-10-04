// lib/core/utils/metin.dart
//
// Türkçe metin karşılaştırma yardımcıları. Dart'ın toLowerCase()'i Türkçe
// İ/I için güvenilir olmadığından harfler önce açıkça ASCII karşılıklarına
// katlanır. İl, ürün ve etiket eşleştirmesinin hepsi bu anahtarı kullanır.

const _harita = {
  'ç': 'c', 'Ç': 'c',
  'ğ': 'g', 'Ğ': 'g',
  'ı': 'i', 'İ': 'i', 'I': 'i',
  'ö': 'o', 'Ö': 'o',
  'ş': 's', 'Ş': 's',
  'ü': 'u', 'Ü': 'u',
  'â': 'a', 'Â': 'a', 'î': 'i', 'Î': 'i', 'û': 'u', 'Û': 'u',
};

/// "İSTANBUL", "istanbul", "İstanbul" → "istanbul"; "Iğdır" → "igdir".
String turkceAnahtar(String s) {
  final sb = StringBuffer();
  for (final ch in s.trim().split('')) {
    sb.write(_harita[ch] ?? ch);
  }
  return sb.toString().toLowerCase();
}

final _ayrac = RegExp(r'[^a-z0-9]+');

/// Metni normalize edilmiş kelimelere böler.
/// "Büyükbaş (Süt)" → ["buyukbas", "sut"].
List<String> kelimeler(String s) =>
    turkceAnahtar(s).split(_ayrac).where((k) => k.isNotEmpty).toList();

/// İki ürün adını esnek karşılaştırır: kelimelerden biri diğerinin tüm
/// kelimelerini içeriyorsa eşleşir. "Büyükbaş (Süt)" ↔ "büyükbaş",
/// "Organik Bal" ↔ "bal" eşleşir; "Arpa" ↔ "Buğday" eşleşmez.
bool urunEslesir(String a, String b) {
  final ka = kelimeler(a).toSet();
  final kb = kelimeler(b).toSet();
  if (ka.isEmpty || kb.isEmpty) return false;
  return ka.containsAll(kb) || kb.containsAll(ka);
}

/// Bir anahtar kelimenin bir kelimeyle eşleşip eşleşmediği. Kısa anahtarlar
/// (<5 harf) yalnızca TAM kelime olarak eşleşir; böylece "arı" → "tarım",
/// "bal" → "balık" gibi yanlış pozitifler oluşmaz. Uzun anahtarlar kelime
/// başı olarak eşleşir ("hayvan" → "hayvancılık").
bool anahtarKelimeEslesir(String kelime, String anahtar) {
  if (anahtar.length < 5) return kelime == anahtar;
  return kelime.startsWith(anahtar);
}
