// Son başvuru tarihi hesapları — saat farkından etkilenmemeli.

import 'package:flutter_test/flutter_test.dart';
import 'package:tesvik_app/core/utils/tarih.dart';

void main() {
  final simdi = DateTime(2026, 10, 4, 18, 30); // akşam saati

  test('son gün bugünse 0 gün ve "Bugün son gün"', () {
    final son = DateTime(2026, 10, 4);
    expect(kalanGun(son, simdi: simdi), 0);
    expect(kalanMetni(son, simdi: simdi), 'Bugün son gün');
    expect(sureDurumu(son, simdi: simdi), SureDurumu.kritik);
  });

  test('dün bittiyse süre doldu', () {
    final son = DateTime(2026, 10, 3);
    expect(kalanGun(son, simdi: simdi), -1);
    expect(sureDurumu(son, simdi: simdi), SureDurumu.doldu);
    expect(kalanMetni(son, simdi: simdi), 'Süre doldu');
  });

  test('yarın ve ileri tarihler', () {
    expect(kalanMetni(DateTime(2026, 10, 5), simdi: simdi), 'Yarın son gün');
    expect(kalanGun(DateTime(2026, 10, 14), simdi: simdi), 10);
    expect(sureDurumu(DateTime(2026, 10, 14), simdi: simdi),
        SureDurumu.yaklasiyor);
    expect(sureDurumu(DateTime(2026, 12, 1), simdi: simdi), SureDurumu.normal);
  });

  test('yaz saati geçişinde gün kaybı olmaz', () {
    // Ekim sonu DST geçişini kapsayan aralık
    final s = DateTime(2026, 10, 20, 23, 59);
    expect(kalanGun(DateTime(2026, 11, 2), simdi: s), 13);
  });

  test('tarih yoksa süresiz', () {
    expect(kalanGun(null), isNull);
    expect(sureDurumu(null), SureDurumu.suresiz);
    expect(kalanMetni(null), 'Süresiz');
  });

  test('biçimler', () {
    expect(tarihUzun(DateTime(2026, 10, 4)), '4 Ekim 2026');
    expect(tarihSaat(DateTime(2026, 1, 2, 3, 4)), '02.01.2026 03:04');
  });
}
