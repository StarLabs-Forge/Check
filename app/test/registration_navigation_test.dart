import 'package:check/main.dart';
import 'package:check/proto/buyer/buyer_flow.dart' show EventDetailScreen;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'demo_only.dart';

void main() {
  testWidgets('el registro directo permanece abierto y permite iniciar sesión', skip: demoOnly != null, (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/registro';
    addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);

    await tester.pumpWidget(const CheckApp());
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Crea tu cuenta'), findsOneWidget);

    await tester.tap(find.text('Inicia sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.byTooltip('Volver'), findsNothing); // sin pantallas de carga debajo
  });

  testWidgets('la app abre directamente en el registro, sin selectores', skip: demoOnly != null, (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/';
    addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);

    await tester.pumpWidget(const CheckApp());
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Crea tu cuenta'), findsOneWidget);
    expect(find.text('Soy comprador'), findsNothing);
    expect(find.text('¿Cómo quieres acceder?'), findsNothing);
  });

  testWidgets('«Comprar en CHECK» abre directamente ese evento', skip: demoOnly != null, (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/comprar?evento=e1';
    addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);

    await tester.pumpWidget(const CheckApp());
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(EventDetailScreen), findsOneWidget);
  });

  testWidgets('el enlace «Probar gratis» abre el registro conservando el contexto', skip: demoOnly != null, (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/registro?origen=prueba';
    addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);

    await tester.pumpWidget(const CheckApp());
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Crea tu cuenta'), findsOneWidget);
    expect(find.textContaining('prueba gratuita de 14 días'), findsOneWidget);
    expect(find.text('Inicia sesión'), findsOneWidget);
  });
}
