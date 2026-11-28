import 'package:check/data/admin_repository.dart';
import 'package:check/theme/app_theme.dart';
import 'package:check/widgets/trial_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

TrialStatus _t(String state, int days) =>
    TrialStatus(state: state, daysLeft: days, endsAt: DateTime(2026, 12, 11));

Future<void> _pump(WidgetTester tester, TrialBanner banner) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: Scaffold(body: banner)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('prueba vigente muestra los días restantes', (tester) async {
    await _pump(tester, TrialBanner(loadStatus: () async => _t('active', 14)));
    expect(find.text('Prueba gratuita: 14 día(s) restantes.'), findsOneWidget);
    expect(find.text('Activar prueba'), findsNothing);
  });

  testWidgets('prueba por vencer avisa y conserva el mensaje de continuidad', (tester) async {
    await _pump(tester, TrialBanner(loadStatus: () async => _t('expiring', 2)));
    expect(find.textContaining('termina en 2 día(s)'), findsOneWidget);
  });

  testWidgets('prueba vencida informa que los datos se conservan, sin bloquear ni cobrar', (tester) async {
    await _pump(tester, TrialBanner(loadStatus: () async => _t('expired', 0)));
    expect(find.textContaining('Tus datos se conservan'), findsOneWidget);
    expect(find.text('Activar prueba'), findsNothing);
  });

  testWidgets('sin prueba ofrece activarla una vez y luego muestra los 14 días', (tester) async {
    var starts = 0;
    await _pump(tester, TrialBanner(loadStatus: () async => null, startTrial: () async { starts++; return _t('active', 14); }));
    await tester.tap(find.text('Activar prueba'));
    await tester.pumpAndSettle();
    expect(starts, 1);
    expect(find.text('Prueba gratuita: 14 día(s) restantes.'), findsOneWidget);
    expect(find.text('Activar prueba'), findsNothing);
  });

  testWidgets('muestra fecha de vencimiento y cómo contratar, sin precios inventados', (tester) async {
    await _pump(tester, TrialBanner(loadStatus: () async => _t('active', 9)));
    expect(find.textContaining('Vence el 11/12/2026'), findsOneWidget);
    expect(find.textContaining('contacta al equipo de CHECK'), findsOneWidget);
    expect(find.textContaining('Bs'), findsNothing);
  });

  testWidgets('plan activo y plan terminado', (tester) async {
    await _pump(tester, TrialBanner(loadStatus: () async => const TrialStatus(state: 'subscribed', daysLeft: 0, plan: 'pro')));
    expect(find.text('Plan Pro activo.'), findsOneWidget);
    await _pump(tester, TrialBanner(key: UniqueKey(), loadStatus: () async => const TrialStatus(state: 'plan_ended', daysLeft: 0)));
    expect(find.textContaining('Tu plan terminó'), findsOneWidget);
    expect(find.text('Activar prueba'), findsNothing);
  });

  test('trial_status admite ends_at nulo (plan contratado)', () {
    final s = TrialStatus.fromMap({'state': 'subscribed', 'plan': 'starter', 'days_left': 0, 'ends_at': null});
    expect(s.endsAt, isNull);
    expect(s.plan, 'starter');
  });

  testWidgets('si el servidor rechaza la activación muestra el motivo', (tester) async {
    await _pump(tester, TrialBanner(
      loadStatus: () async => null,
      startTrial: () async => throw const PostgrestException(message: 'venue_required'),
    ));
    await tester.tap(find.text('Activar prueba'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Completa los datos de tu local'), findsOneWidget);
  });

  testWidgets('sin migración o sin conexión el banner no se muestra', (tester) async {
    await _pump(tester, TrialBanner(loadStatus: () async => throw StateError('migration_14_missing')));
    expect(find.byType(Text), findsNothing);
  });
}
