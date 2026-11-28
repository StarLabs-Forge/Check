import 'dart:io';

import 'package:check/config/demo_mode.dart';
import 'package:check/proto/buyer/buyer_flow.dart';
import 'package:check/proto/data/proto_store.dart';
import 'package:check/screens/complete_profile_screen.dart';
import 'package:check/screens/login_screen.dart';
import 'package:check/screens/register_screen.dart';
import 'package:check/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Comprueba que las pantallas «de un paso» (acceso, login, compra, pago)
/// se vean completas sin hacer scroll en celulares y laptops, y que no haya
/// overflows de layout. Mide el scroll vertical que sobraría en cada una.
/// El runner de tests no trae Inter y la fuente de reemplazo (Ahem) es mucho
/// más ancha que una real, lo que infla los textos. Se carga Roboto del SDK
/// (métricas muy cercanas a Inter) bajo los nombres de familia de GoogleFonts.
Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? 'C:/Users/PC/dev/flutter';
  final dir = '$root/bin/cache/artifacts/material_fonts';
  const map = {
    'Inter_regular': 'roboto-regular.ttf',
    'Inter_500': 'roboto-medium.ttf',
    'Inter_600': 'roboto-bold.ttf',
    'Inter_700': 'roboto-bold.ttf',
    'Inter_800': 'roboto-black.ttf',
  };
  for (final e in map.entries) {
    final f = File('$dir/${e.value}');
    if (!f.existsSync()) continue;
    final loader = FontLoader(e.key)..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    await loader.load();
  }
}

/// Pantallas del comprador que leen eventos/pedidos sembrados por el store de
/// DEMO (ids e1, o1042...). Sin `--dart-define=DEMO=true` el store arranca vacío
/// y no hay nada que medir: la prueba se OMITE declarando el motivo, no se oculta.
const _demoScreens = {
  'Detalle de evento', 'Elegir entradas', 'Datos del comprador',
  'Pedido en verificación', 'Pedido aprobado (2 QR)', 'Pedido rechazado', 'Consultar pedido',
};
String? _needsDemo(bool needs) => (needs && !kDemo) ? 'Requiere datos demo: flutter test --dart-define=DEMO=true' : null;

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadFonts();
  });

  final sizes = <String, Size>{
    'celular chico 360x740': const Size(360, 740),
    'celular 390x844': const Size(390, 844),
    'laptop 1366x768': const Size(1366, 768),
    'laptop corta 1280x680': const Size(1280, 680),
  };

  final screens = <String, Widget Function()>{
    'Login': () => const LoginScreen(),
    'Registro': () => const RegisterScreen(),
    'Completar perfil': () => const CompleteProfileScreen(),
    'Detalle de evento': () => const EventDetailScreen('e1'),
    'Elegir entradas': () => const TicketSelectionScreen('e1'),
    'Datos del comprador': () => const BuyerDataScreen(eventId: 'e1', qty: {'e1g': 2}),
    'Pedido en verificación': () => const OrderScreen('o1042'),
    'Pedido aprobado (2 QR)': () => const OrderScreen('o1045'),
    'Pedido rechazado': () => const OrderScreen('o1046'),
    'Consultar pedido': () => const OrderLookupScreen(),
  };

  // Máximo de scroll tolerado (px) para considerar que «cabe de un vistazo».
  const tolerance = 1.0;

  for (final entry in sizes.entries) {
    for (final s in screens.entries) {
      testWidgets('${s.key} · ${entry.key}', skip: _needsDemo(_demoScreens.contains(s.key)) != null, (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: s.value()));
        await tester.pump(const Duration(milliseconds: 1200));

        var extra = 0.0;
        for (final st in tester.stateList<ScrollableState>(find.byType(Scrollable))) {
          if (st.position.axis == Axis.vertical) {
            final e = st.position.maxScrollExtent;
            if (e > extra) extra = e;
          }
        }
        // ignore: avoid_print
        print('FIT ${entry.key.padRight(22)} ${s.key.padRight(26)} scroll sobrante: ${extra.toStringAsFixed(0)} px');
        expect(extra, lessThanOrEqualTo(tolerance), reason: '${s.key} necesita ${extra.toStringAsFixed(0)} px de scroll en ${entry.key}');
      });
    }
  }

  // Ticket múltiple y pago pendiente (necesitan crear el pedido antes).
  for (final entry in sizes.entries) {
    testWidgets('Pago pendiente · ${entry.key}', skip: _needsDemo(true) != null, (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final o = await ProtoStore.instance.createOrder(eventId: 'e1', qty: {'e1g': 2}, name: 'Ana Pruebas', ci: '1234567', phone: '71234567');
      await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: OrderScreen(o.id)));
      await tester.pump(const Duration(milliseconds: 1200));
      var extra = 0.0;
      for (final st in tester.stateList<ScrollableState>(find.byType(Scrollable))) {
        if (st.position.axis == Axis.vertical && st.position.maxScrollExtent > extra) extra = st.position.maxScrollExtent;
      }
      // ignore: avoid_print
      print('FIT ${entry.key.padRight(22)} ${'Pago pendiente'.padRight(26)} scroll sobrante: ${extra.toStringAsFixed(0)} px');
      expect(extra, lessThanOrEqualTo(tolerance), reason: 'Pago pendiente necesita ${extra.toStringAsFixed(0)} px de scroll en ${entry.key}');
    });
  }
}
