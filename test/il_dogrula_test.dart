// İl doğrulama/eşleştirme yardımcılarının (O2 + O7) birim testleri.

import 'package:flutter_test/flutter_test.dart';
import 'package:tesvik_app/models/profil_model.dart';

void main() {
  group('ilDogrula', () {
    test('kanonik adı olduğu gibi döndürür', () {
      expect(ilDogrula('Ankara'), 'Ankara');
    });

    test('büyük/küçük harf farkını düzeltir (Türkçe dahil)', () {
      expect(ilDogrula('ankara'), 'Ankara');
      expect(ilDogrula('ANKARA'), 'Ankara');
      expect(ilDogrula('istanbul'), 'İstanbul');
      expect(ilDogrula('İSTANBUL'), 'İstanbul');
      expect(ilDogrula('ığdır'), 'Iğdır');
      expect(ilDogrula('ŞANLIURFA'), 'Şanlıurfa');
    });

    test('alt-bölge ve plaka kodunu temizler', () {
      expect(ilDogrula('Ankara/Polatlı'), 'Ankara');
      expect(ilDogrula('06 Ankara'), 'Ankara');
      expect(ilDogrula('  İzmir  '), 'İzmir');
    });

    test('geçersiz/boş değerde null döner', () {
      expect(ilDogrula(null), isNull);
      expect(ilDogrula(''), isNull);
      expect(ilDogrula('Berlin'), isNull);
      expect(ilDogrula('12345'), isNull);
    });
  });

  group('ilEslesir', () {
    test('Türkçe-duyarlı eşleşme', () {
      expect(ilEslesir('İstanbul', 'istanbul'), isTrue);
      expect(ilEslesir('ANKARA', 'Ankara'), isTrue);
      expect(ilEslesir('Iğdır', 'ığdır'), isTrue);
    });

    test('farklı iller eşleşmez', () {
      expect(ilEslesir('Ankara', 'İzmir'), isFalse);
    });

    test('boş/null eşleşmez', () {
      expect(ilEslesir(null, 'Ankara'), isFalse);
      expect(ilEslesir('', 'Ankara'), isFalse);
      expect(ilEslesir('Ankara', ''), isFalse);
    });
  });
}
