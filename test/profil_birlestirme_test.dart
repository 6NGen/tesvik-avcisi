// Belge analizinden gelen PROFIL_JSON ile profil birleştirme/oluşturma.

import 'package:flutter_test/flutter_test.dart';
import 'package:tesvik_app/models/profil_model.dart';
import 'package:tesvik_app/models/tesvik_model.dart';
import 'package:tesvik_app/services/gemini_servisi.dart';
import 'package:tesvik_app/services/profil_birlestirme.dart';

void main() {
  const mevcut = ProfilModel(
    userId: 'u1',
    ureticiTipleri: [UreticiTipi.ciftci],
    il: 'Konya',
    urunler: ['Buğday'],
    dekar: 50,
    bildirimSonTarih: false,
    bildirimYeniHibe: false,
  );

  group('birlestir', () {
    test('bildirim tercihlerini korur', () {
      final yeni = ProfilBirlestirme.birlestir(mevcut, {'il': 'Ankara'})!;
      expect(yeni.il, 'Ankara');
      expect(yeni.bildirimSonTarih, isFalse);
      expect(yeni.bildirimYeniHibe, isFalse);
    });

    test('ondalıklı / metin sayıları kabul eder (as int? hatası)', () {
      final yeni = ProfilBirlestirme.birlestir(mevcut, {
        'kovan_sayisi': 12.0,
        'hayvan_sayisi': '30',
        'dekar': '75,5',
      })!;
      expect(yeni.kovanSayisi, 12);
      expect(yeni.hayvanSayisi, 30);
      expect(yeni.dekar, 75.5);
    });

    test('geçersiz il ve bilinmeyen tip mevcut değeri bozmaz', () {
      final yeni = ProfilBirlestirme.birlestir(mevcut, {
        'il': 'Berlin',
        'uretici_tipleri': ['balikci'],
        'urunler': ['Arpa'],
      })!;
      expect(yeni.il, 'Konya');
      expect(yeni.ureticiTipleri, [UreticiTipi.ciftci]);
      expect(yeni.urunler, ['Arpa']);
    });

    test('değişiklik yoksa null (gereksiz yazım yok)', () {
      expect(
        ProfilBirlestirme.birlestir(
            mevcut, {'il': 'KONYA', 'urunler': ['Buğday'], 'dekar': null}),
        isNull,
      );
    });
  });

  group('olustur', () {
    test('il veya ürün yoksa oluşturmaz', () {
      expect(ProfilBirlestirme.olustur('u2', {'dekar': 10}), isNull);
    });

    test('geçerli veriden profil kurar', () {
      final p = ProfilBirlestirme.olustur('u2', {
        'il': '06 Ankara',
        'uretici_tipleri': ['arici', 'arici'],
        'urunler': ['Süzme Bal', ' süzme bal ', ''],
        'kovan_sayisi': 40,
      })!;
      expect(p.il, 'Ankara');
      expect(p.ureticiTipleri, [UreticiTipi.arici]);
      expect(p.urunler, ['Süzme Bal']);
      expect(p.kovanSayisi, 40);
    });
  });

  group('Gemini çıktısı', () {
    test('PROFIL_JSON ayrıştırılır ve kullanıcı metninden temizlenir', () {
      const metin = 'Analiz metni\nKRITIK_UYARI\n'
          'PROFIL_JSON: {"il":"Konya","urunler":["Buğday"]}';
      expect(GeminiServisi.profilJsonCikar(metin)?['il'], 'Konya');
      expect(analizMetniTemizle(metin), 'Analiz metni');
    });

    test('bozuk JSON null döner', () {
      expect(GeminiServisi.profilJsonCikar('PROFIL_JSON:{bozuk}'), isNull);
    });
  });

  group('ProfilModel.fromJson', () {
    test('bilinmeyen tipleri atar, eski formata düşer', () {
      final p = ProfilModel.fromJson({
        'user_id': 'u',
        'uretici_tipleri': ['xyz'],
        'uretici_tipi': 'arici',
        'kovan_sayisi': 10.0,
      });
      expect(p.ureticiTipleri, [UreticiTipi.arici]);
      expect(p.kovanSayisi, 10);
      expect(p.bildirimSonTarih, isTrue);
    });
  });
}
