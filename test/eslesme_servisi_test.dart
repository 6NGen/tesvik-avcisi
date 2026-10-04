// Eşleştirme motoru testleri (ana liste + detay ekranı aynı motoru kullanır).

import 'package:flutter_test/flutter_test.dart';
import 'package:tesvik_app/models/profil_model.dart';
import 'package:tesvik_app/models/tesvik_model.dart';
import 'package:tesvik_app/services/eslesme_servisi.dart';

ProfilModel _profil({
  List<UreticiTipi> tipler = const [UreticiTipi.ciftci],
  String il = 'Konya',
  List<String> urunler = const ['Buğday'],
  double? dekar,
}) =>
    ProfilModel(
      userId: 'u1',
      ureticiTipleri: tipler,
      il: il,
      urunler: urunler,
      dekar: dekar,
    );

TesvikModel _tesvik({
  String id = 't',
  List<String> iller = const [],
  List<String> urunler = const [],
  List<String> etiketler = const [],
  int? minDekar,
}) =>
    TesvikModel(
      id: id,
      isim: 'Test $id',
      uygunIller: iller,
      uygunUrunler: urunler,
      etiketler: etiketler,
      minDekar: minDekar,
    );

void main() {
  group('il kuralı', () {
    test('il listesi boşsa tüm Türkiye — uygun', () {
      final s = EslesmeServisi.degerlendir(_tesvik(), _profil());
      expect(s.uygun, isTrue);
      expect(s.engeller, isEmpty);
    });

    test('il Türkçe-duyarsız eşleşir', () {
      final s = EslesmeServisi.degerlendir(
          _tesvik(iller: ['KONYA', 'Karaman']), _profil());
      expect(s.uygun, isTrue);
    });

    test('başka ile özel teşvik elenir', () {
      final s = EslesmeServisi.degerlendir(
          _tesvik(iller: ['İzmir']), _profil());
      expect(s.uygun, isFalse);
      expect(s.engeller.single, contains('Konya'));
    });
  });

  group('ürün kuralı', () {
    test('büyük/küçük harf ve parantezden bağımsız eşleşir', () {
      final s = EslesmeServisi.degerlendir(
        _tesvik(urunler: ['büyükbaş']),
        _profil(
            tipler: [UreticiTipi.hayvancilik], urunler: ['Büyükbaş (Süt)']),
      );
      expect(s.uygun, isTrue);
    });

    test('hiçbir ürün eşleşmezse elenir', () {
      final s = EslesmeServisi.degerlendir(
          _tesvik(urunler: ['Fındık']), _profil());
      expect(s.uygun, isFalse);
    });

    test('farklı ürünler yanlışlıkla eşleşmez', () {
      final s = EslesmeServisi.degerlendir(
          _tesvik(urunler: ['Arpa']), _profil(urunler: ['Buğday']));
      expect(s.uygun, isFalse);
    });
  });

  group('üretici tipi', () {
    test('"tarım" etiketi arıcıyla EŞLEŞMEZ ("arı" alt-dize hatası)', () {
      final s = EslesmeServisi.degerlendir(
        _tesvik(etiketler: ['tarım']),
        _profil(tipler: [UreticiTipi.arici], urunler: ['Süzme Bal']),
      );
      expect(s.nedenler.where((n) => n.contains('Arıcı')), isEmpty);
      expect(s.notlar, isNotEmpty);
    });

    test('"balıkçılık" etiketi arıcıyla eşleşmez ("bal" hatası)', () {
      final s = EslesmeServisi.degerlendir(
        _tesvik(etiketler: ['balıkçılık']),
        _profil(tipler: [UreticiTipi.arici], urunler: ['Süzme Bal']),
      );
      expect(s.nedenler.where((n) => n.contains('Arıcı')), isEmpty);
    });

    test('"arıcılık" etiketi arıcıyla eşleşir', () {
      final s = EslesmeServisi.degerlendir(
        _tesvik(etiketler: ['Arıcılık Desteği']),
        _profil(tipler: [UreticiTipi.arici], urunler: ['Süzme Bal']),
      );
      expect(s.nedenler.any((n) => n.contains('Arıcı')), isTrue);
    });

    test('tip uyuşmazlığı ELEMEZ, yalnızca not düşer', () {
      final s = EslesmeServisi.degerlendir(
        _tesvik(etiketler: ['hayvancılık']),
        _profil(),
      );
      expect(s.uygun, isTrue);
      expect(s.notlar, isNotEmpty);
    });
  });

  group('arazi', () {
    test('yeterli dekar puan artırır', () {
      final az = EslesmeServisi.degerlendir(
          _tesvik(minDekar: 50), _profil(dekar: 10));
      final cok = EslesmeServisi.degerlendir(
          _tesvik(minDekar: 50), _profil(dekar: 100));
      expect(az.uygun, isTrue);
      expect(cok.puan, greaterThan(az.puan));
      expect(az.notlar.single, contains('50'));
    });
  });

  group('eslestir', () {
    test('uygun olmayanları atar, puana göre sıralar', () {
      final sonuc = EslesmeServisi.eslestir(
        tesvikler: [
          _tesvik(id: 'genel'),
          _tesvik(id: 'izmir', iller: ['İzmir']),
          _tesvik(id: 'ozel', iller: ['Konya'], urunler: ['Buğday']),
        ],
        profil: _profil(),
      );
      expect(sonuc.map((s) => s.tesvik.id), ['ozel', 'genel']);
      expect(sonuc.every((s) => s.puan >= 0 && s.puan <= 1), isTrue);
    });
  });
}
