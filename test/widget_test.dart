// Teşvik Avcısı — widget smoke testleri.
//
// Tam uygulama açılışta Supabase ve Firebase'e bağlı olduğundan mock'lanmadan
// pump edilemez. Burada servis bağımlılığı olmayan ortak bileşenler açık ve
// koyu temada render edilir.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tesvik_app/core/theme/app_theme.dart';
import 'package:tesvik_app/models/profil_model.dart';
import 'package:tesvik_app/models/tesvik_model.dart';
import 'package:tesvik_app/providers/tesvik_provider.dart';
import 'package:tesvik_app/services/eslesme_servisi.dart';
import 'package:tesvik_app/widgets/ortak.dart';
import 'package:tesvik_app/widgets/tesvik_karti.dart';

Widget _sar(Widget child, ThemeData tema) => MaterialApp(
      theme: tema,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  test('Temalar AppRenkler uzantısını taşır', () {
    expect(AppTheme.light.extension<AppRenkler>(), isNotNull);
    expect(AppTheme.dark.extension<AppRenkler>(), isNotNull);
    expect(AppTheme.dark.colorScheme.brightness, Brightness.dark);
  });

  for (final (ad, tema) in [('açık', AppTheme.light), ('koyu', AppTheme.dark)]) {
    testWidgets('TesvikKarti render olur ($ad tema)', (tester) async {
      final tesvik = TesvikModel(
        id: '1',
        isim: 'Genç Çiftçi Projesi Desteği',
        kurum: 'Tarım ve Orman Bakanlığı',
        sonBasvuruTarihi: DateTime.now().add(const Duration(days: 5)),
        uygunIller: const ['Konya'],
      );
      const profil = ProfilModel(
        userId: 'u',
        ureticiTipleri: [UreticiTipi.ciftci],
        il: 'Konya',
        urunler: ['Buğday'],
      );
      final satir =
          TesvikSatiri(tesvik, EslesmeServisi.degerlendir(tesvik, profil));

      await tester.pumpWidget(_sar(TesvikKarti(satir: satir), tema));

      expect(find.text('Genç Çiftçi Projesi Desteği'), findsOneWidget);
      expect(find.text('5 gün kaldı'), findsOneWidget);
      expect(find.textContaining('uyum'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('DurumGorunumu butonu tetiklenir', (tester) async {
    var basildi = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: DurumGorunumu(
          ikon: Icons.eco_outlined,
          baslik: 'Boş',
          butonEtiketi: 'Tekrar dene',
          onButon: () => basildi = true,
        ),
      ),
    ));
    await tester.tap(find.text('Tekrar dene'));
    expect(basildi, isTrue);
  });
}
