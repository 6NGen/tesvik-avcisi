// Teşvik Avcısı — temel smoke test.
//
// Tam uygulama (TesvikApp) açılışta Supabase ve Firebase'e bağlı olduğundan,
// bu servisler mock'lanmadan pump edilemez. Bu smoke test, servis bağımlılığı
// olmayan saf bir widget'ı (yükleniyor ekranı) doğrular: uygulama bileşenleri
// derleniyor ve render oluyor.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tesvik_app/core/theme/app_theme.dart';

void main() {
  testWidgets('AppTheme geçerli bir ThemeData üretir', (tester) async {
    final theme = AppTheme.light;
    expect(theme, isA<ThemeData>());
    expect(theme.useMaterial3, isTrue);
  });

  testWidgets('Yükleniyor göstergesi render olur', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
