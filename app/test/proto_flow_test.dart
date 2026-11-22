import 'package:check/proto/data/proto_store.dart';
import 'package:check/proto/proto_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Recorre los flujos del prototipo en tres anchos. Cualquier overflow de
/// layout lanza una excepción de render y hace fallar la prueba.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final size in const [Size(360, 740), Size(768, 1024), Size(1280, 800)]) {
    testWidgets('flujos completos a ${size.width.toInt()} px', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      Future<void> tapText(String t, {bool last = false}) async {
        final f = find.text(t);
        expect(f, findsWidgets, reason: 'no se encontró "$t"');
        final target = last ? f.last : f.first;
        await tester.ensureVisible(target);
        await tester.pump();
        await tester.tap(target);
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pump(const Duration(milliseconds: 700));
      }

      Future<void> buy(String who) async {
        await tester.pump(const Duration(seconds: 5)); // deja caer los snackbars
        await tapText('Comprador');
        await tapText('Eclipse Party');
        await tapText('Comprar entradas');
        await tester.tap(find.byTooltip('Agregar una').first);
        await tester.pump();
        await tapText('Continuar');
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), who);
        await tester.enterText(fields.at(1), '1234567 LP');
        await tester.enterText(fields.at(2), '71234567');
        await tester.pump();
        await tapText('Continuar al pago');
        // El reloj es el real (los pump no lo adelantan): acepta 15:00 a 14:00.
        expect(find.byWidgetPredicate((w) => w is Text && RegExp(r'^1[45]:\d\d$').hasMatch(w.data ?? '')), findsOneWidget, reason: 'cuenta regresiva de 15 min');
        expect(find.textContaining('no válido para pagar'), findsOneWidget);
      }

      await tester.pumpWidget(const ProtoApp());
      final store = ProtoStore.instance;

      // a) comprador → verificando
      await buy('Ana Pruebas');
      await tapText('Ya pagué');
      expect(find.text('Estamos verificando tu pago'), findsOneWidget);
      expect(find.textContaining('Todavía no se ha confirmado'), findsOneWidget);
      final o1 = store.orders.last;
      expect(o1.status, OrderStatus.verifying);
      // El pago se muestra como ventana emergente: se cierra con su botón.
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(Scaffold).first)).popUntil((r) => r.isFirst);
      await tester.pumpAndSettle();

      // b) admin aprueba con confirmación
      await tapText('Administrador del local');
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(o1.number), findsWidgets);
      final reviewO1 = find.text('Revisar pago').at(store.pending.indexOf(o1));
      await tester.ensureVisible(reviewO1);
      await tester.tap(reviewO1);
      await tester.pumpAndSettle();
      await tapText('Aprobar pago');
      expect(find.text('¿Aprobar este pago?'), findsOneWidget);
      await tester.tap(find.text('Sí, aprobar'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(o1.status, OrderStatus.approved);
      expect(o1.ticketCodes.length, o1.ticketCount);
      Navigator.of(tester.element(find.byType(Scaffold).first)).popUntil((r) => r.isFirst);
      await tester.pumpAndSettle();

      // comprador ve aprobado con QR y descarga
      await tapText('Comprador');
      await tapText('Mi pedido');
      await tester.enterText(find.byType(TextField).first, o1.number);
      await tapText('Ver pedido');
      expect(find.text('Pago aprobado'), findsOneWidget);
      expect(find.textContaining('Cuida tu código QR y no lo compartas'), findsOneWidget);
      expect(find.text('Descargar QR'), findsNWidgets(o1.ticketCount));
      Navigator.of(tester.element(find.byType(Scaffold).first)).popUntil((r) => r.isFirst);
      await tester.pumpAndSettle();

      // c) rechazo con motivo obligatorio
      await buy('Beto Pruebas');
      await tapText('Ya pagué');
      final o2 = store.orders.last;
      final leftBefore = store.remaining(store.events.first.types.first);
      Navigator.of(tester.element(find.byType(Scaffold).first)).popUntil((r) => r.isFirst);
      await tester.pumpAndSettle();
      await tapText('Administrador del local');
      await tester.pump(const Duration(seconds: 1));
      final reviewO2 = find.text('Revisar pago').at(store.pending.indexOf(o2));
      await tester.ensureVisible(reviewO2);
      await tester.tap(reviewO2);
      await tester.pumpAndSettle();
      await tapText('Rechazar pago');
      expect(find.textContaining('irreversible'), findsOneWidget);
      final rejectBtn = find.widgetWithText(ElevatedButton, 'Rechazar definitivamente');
      expect(tester.widget<ElevatedButton>(rejectBtn).onPressed, isNull, reason: 'motivo obligatorio');
      await tester.enterText(find.byType(TextField).last, 'No hay depósito');
      await tester.pump();
      await tester.tap(rejectBtn);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(o2.status, OrderStatus.rejected);
      expect(store.remaining(store.events.first.types.first), greaterThan(leftBefore - 1));
      Navigator.of(tester.element(find.byType(Scaffold).first)).popUntil((r) => r.isFirst);
      await tester.pumpAndSettle();
      await tapText('Comprador');
      await tapText('Mi pedido');
      await tester.enterText(find.byType(TextField).first, o2.number);
      await tapText('Ver pedido');
      expect(find.text('Pago rechazado'), findsOneWidget);
      expect(find.textContaining('Devol'), findsNothing);
      Navigator.of(tester.element(find.byType(Scaffold).first)).popUntil((r) => r.isFirst);
      await tester.pumpAndSettle();

      // d) revocar → verificador denegado
      await tapText('Administrador del local');
      await tapText('Delegación');
      await tapText('Revocar permiso');
      await tapText('Revocar', last: true);
      await tester.pumpAndSettle();
      expect(store.verifierEnabled('diego'), isFalse);
      Navigator.of(tester.element(find.byType(Scaffold).first)).popUntil((r) => r.isFirst);
      await tester.pumpAndSettle();
      await tapText('Verificador delegado');
      expect(find.text('Acceso denegado'), findsOneWidget);
      Navigator.of(tester.element(find.byType(Scaffold).first)).popUntil((r) => r.isFirst);
      await tester.pumpAndSettle();

      // e) conceder otra vez + conflicto de doble decisión
      await tapText('Administrador del local');
      await tapText('Delegación');
      await tapText('Conceder permiso');
      await tapText('Conceder', last: true);
      await tester.pumpAndSettle();
      expect(store.verifierEnabled('diego'), isTrue);
      Navigator.of(tester.element(find.byType(Scaffold).first)).popUntil((r) => r.isFirst);
      await tester.pumpAndSettle();
      await buy('Carla Pruebas');
      await tapText('Ya pagué');
      final o3 = store.orders.last;
      Navigator.of(tester.element(find.byType(Scaffold).first)).popUntil((r) => r.isFirst);
      await tester.pumpAndSettle();
      await tapText('Verificador delegado');
      await tester.pump(const Duration(seconds: 1));
      final reviewO3 = find.text('Revisar pago').at(store.pending.indexOf(o3));
      await tester.ensureVisible(reviewO3);
      await tester.tap(reviewO3);
      await tester.pumpAndSettle();
      await tapText('Demo: otro verificador resuelve primero');
      expect(o3.status, OrderStatus.approved);
      final approvals = store.audit.where((a) => a.orderNumber == o3.number && a.action == 'Aprobó pago').length;
      await tapText('Aprobar pago');
      await tester.tap(find.text('Sí, aprobar'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.textContaining('Conflicto'), findsWidgets);
      expect(store.audit.where((a) => a.orderNumber == o3.number && a.action == 'Aprobó pago').length, approvals);
      expect(store.audit.any((a) => a.orderNumber == o3.number && a.action.contains('bloqueado')), isTrue);
      Navigator.of(tester.element(find.byType(Scaffold).first)).popUntil((r) => r.isFirst);
      await tester.pumpAndSettle();

      // f) superadmin: 5 secciones, sin aprobar pagos
      await tapText('Superadministrador');
      for (final s in ['Resumen', 'Locales', 'Eventos', 'Auditoría', 'Plataforma']) {
        await tapText(s, last: size.width < 700);
        expect(find.text('Aprobar pago'), findsNothing);
        expect(find.text('Revisar pago'), findsNothing);
        if (s == 'Auditoría') expect(find.textContaining('Solo lectura'), findsWidgets);
      }
    });
  }

  test('expiración libera cupos', () async {
    final s = ProtoStore.instance;
    final t = s.events.first.types.first;
    final before = s.remaining(t);
    final o = await s.createOrder(eventId: s.events.first.id, qty: {t.id: 2}, name: 'X Y', ci: '1234567', phone: '71234567');
    expect(s.remaining(t), before - 2);
    await s.cancelOrder(o.id);
    expect(s.remaining(t), before);
  });
}
