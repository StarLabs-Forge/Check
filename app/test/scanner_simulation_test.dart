import 'package:check/config/demo_mode.dart';
import 'package:check/staff/data/mock_staff_repository.dart';
import 'package:check/staff/data/staff_models.dart';
import 'package:check/staff/data/staff_repository.dart';
import 'package:check/staff/staff_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Hace de repositorio real: si la simulación llega a validar contra él, falla.
class _RealRepo implements StaffRepository {
  int scans = 0;

  @override
  Future<void> signOut() async {}

  @override
  Future<bool> isOnline() async => true;

  @override
  Future<List<StaffEvent>> assignedEvents() async => [
        StaffEvent(id: 'real-1', name: 'Evento real', startsAt: DateTime(2026, 12, 5, 18), capacity: 50, checkins: 0),
      ];

  @override
  Future<ScanOutcome> scanQr({required String eventId, required String token}) async {
    scans++;
    return const ScanOutcome.denied();
  }
}

void main() {
  testWidgets('con datos reales se marca como simulación y no toca el repositorio', (tester) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = _RealRepo();
    await tester.pumpWidget(StaffApp(repository: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar Scanner'));
    await tester.pumpAndSettle();
    expect(find.text('SIMULACIÓN · No registra ingresos'), findsOneWidget);

    for (final (button, title) in [
      ('Válido', 'ACCESO PERMITIDO'),
      ('Ya usado', 'YA REGISTRADO'),
      ('Inválido', 'ACCESO DENEGADO'),
    ]) {
      await tester.tap(find.text(button));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text(title), findsOneWidget);
      expect(find.text('SIMULACIÓN · No registra ingresos'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2600));
      await tester.pumpAndSettle();
    }
    expect(repo.scans, 0);
    expect(tester.takeException(), isNull);
  }, skip: !kScanSimulation);

  testWidgets('la simulación muestra un QR, valida y registra el ingreso', (tester) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(StaffApp());
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.tap(find.text('Iniciar Scanner'));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);

    await tester.tap(find.text('Válido'));
    await tester.pump();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Leyendo código…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500)); // barrido
    await tester.pump(const Duration(milliseconds: 400)); // validación
    await tester.pump(const Duration(milliseconds: 600)); // transición
    expect(find.text('ACCESO PERMITIDO'), findsOneWidget);
    expect(find.text('144 / 200 ingresados'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2600)); // retorno automático
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('"Válido" sigue funcionando al agotar los invitados de ejemplo', () async {
    final repo = MockStaffRepository();
    for (var i = 0; i < 10; i++) {
      final outcome = await repo.scanQr(eventId: 'ev-eclipse', token: 'VALID');
      expect(outcome.kind, ScanResultKind.success);
    }
  });
}
