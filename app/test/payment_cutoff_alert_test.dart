import 'package:check/data/admin_repository.dart';
import 'package:check/theme/app_theme.dart';
import 'package:check/widgets/payment_cutoff_alert.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> _pump(WidgetTester t, PaymentCutoffAlert alert) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await t.pumpWidget(MaterialApp(theme: AppTheme.dark, home: Scaffold(body: alert)));
  await t.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('suma los pagos pendientes, aclara que nada se anula y permite revisarlos', (t) async {
    var reviewed = false;
    await _pump(t, PaymentCutoffAlert(
      load: () async => const [CutoffAlert(eventName: 'Eclipse', pending: 2), CutoffAlert(eventName: 'Neón', pending: 1)],
      onReview: () => reviewed = true,
    ));
    expect(find.textContaining('3 pago(s) sin revisar'), findsOneWidget);
    expect(find.text('Eclipse: 2 pendiente(s)'), findsOneWidget);
    expect(find.textContaining('siguen reservados'), findsOneWidget);
    await t.tap(find.text('Revisar pagos'));
    expect(reviewed, isTrue);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('sin pendientes no muestra nada y vuelve a consultar cada minuto', (t) async {
    var calls = 0;
    await _pump(t, PaymentCutoffAlert(load: () async {
      calls++;
      return const [];
    }));
    expect(find.byType(Text), findsNothing);
    await t.pump(const Duration(seconds: 61));
    expect(calls, 2);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('si la consulta falla lo dice', (t) async {
    await _pump(t, PaymentCutoffAlert(load: () async => throw StateError('sin red')));
    expect(find.textContaining('No pudimos comprobar'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
