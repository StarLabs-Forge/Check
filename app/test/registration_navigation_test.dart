import 'package:check/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  testWidgets('el registro directo permanece abierto y permite iniciar sesión', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/registro';
    addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);

    await tester.pumpWidget(const CheckApp());
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Crea tu cuenta'), findsOneWidget);

    await tester.tap(find.text('Inicia sesión'));
    await tester.pumpAndSettle();
    expect(find.text('¿Cómo quieres acceder?'), findsOneWidget);
  });
}
