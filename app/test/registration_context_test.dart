import 'package:check/config/demo_mode.dart';
import 'package:check/screens/register_screen.dart';
import 'package:check/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  Future<void> pump(WidgetTester t, String? origin) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    t.view.physicalSize = const Size(1280, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(theme: AppTheme.dark, home: RegisterScreen(origin: origin)));
    await t.pump(const Duration(seconds: 2));
  }

  testWidgets('origen=prueba conserva el contexto y mantiene el acceso a iniciar sesión', (t) async {
    await pump(t, 'prueba');
    expect(find.textContaining('prueba gratuita de 14 días'), findsOneWidget);
    expect(find.text('Inicia sesión'), findsOneWidget);
  });

  testWidgets('sin origen no muestra avisos de contexto', (t) async {
    await pump(t, null);
    expect(find.textContaining('prueba gratuita'), findsNothing);
  });

  testWidgets('origen=demo solo declara "DEMO" en la build demo', (t) async {
    await pump(t, 'demo');
    expect(find.textContaining('DEMO'), kDemo ? findsOneWidget : findsNothing);
  });
}
