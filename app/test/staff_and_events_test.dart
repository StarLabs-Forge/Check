import 'package:flutter_test/flutter_test.dart';

import 'package:check/data/demo_admin_data.dart';
import 'package:check/proto/data/proto_store.dart';
import 'package:check/services/app_session.dart';
import 'package:check/staff/data/staff_access.dart';

import 'demo_only.dart';

void main() {
  group('editar eventos (demo)', skip: demoOnly, () {
    final d = DemoAdminData.instance;
    final s = DateTime.now().toUtc().add(const Duration(days: 3));

    test('rechaza capacidad por debajo de lo vendido', () async {
      expect(
        () => d.updateEvent(id: 'ev-eclipse', name: 'X', startsAt: s, endsAt: s.add(const Duration(hours: 4)), capacity: 5, paid: true, price: 50),
        throwsA(predicate((e) => e.toString().contains('capacity_below_sold'))),
      );
    });

    test('rechaza cambiar el precio con entradas vendidas', () async {
      expect(
        () => d.updateEvent(id: 'ev-eclipse', name: 'X', startsAt: s, endsAt: s.add(const Duration(hours: 4)), capacity: 300, paid: true, price: 99),
        throwsA(predicate((e) => e.toString().contains('price_locked_with_sales'))),
      );
    });

    test('permite editar nombre y capacidad válidos', () async {
      await d.updateEvent(id: 'ev-techno', name: 'Techno 2', startsAt: s, endsAt: s.add(const Duration(hours: 5)), capacity: 250, paid: true, price: 70);
      final e = await d.getEvent('ev-techno');
      expect(e!.name, 'Techno 2');
      expect(e.capacity, 250);
    });

    test('rechaza fin anterior al inicio', () async {
      expect(
        () => d.updateEvent(id: 'ev-techno', name: 'X', startsAt: s, endsAt: s.subtract(const Duration(hours: 1)), capacity: 100, paid: false),
        throwsA(predicate((e) => e.toString().contains('invalid_dates'))),
      );
    });
  });

  test('demo respeta las transiciones de estado existentes', skip: demoOnly != null, () async {
    final d = DemoAdminData.instance;
    await d.setEventStatus('ev-techno', 'draft');
    expect((await d.getEvent('ev-techno'))!.dbStatus, 'draft');
    await expectLater(
      d.setEventStatus('ev-techno', 'finished'),
      throwsA(predicate((e) => e.toString().contains('invalid_status_transition'))),
    );
    await d.setEventStatus('ev-techno', 'active');
  });

  group('permisos de staff (demo)', skip: demoOnly, () {
    final store = ProtoStore.instance;

    test('una cuenta creada solo con scanQr no puede verificar pagos', () async {
      store.createStaffAccount(name: 'Ana Test', email: 'ana@test.demo', job: 'Puerta', permissions: {StaffPermission.scanQr});
      AppSession.signInDemo('ana@test.demo');
      expect(AppSession.profile.value?.role, 'staff');
      final a = await StaffAccess.load();
      expect(a.can(StaffPermission.scanQr), isTrue);
      expect(a.can(StaffPermission.verifyPayments), isFalse);
      expect(a.can(StaffPermission.viewEvents), isFalse);
    });

    test('desactivar la cuenta bloquea todos los permisos', () async {
      final acc = store.staffAccounts.firstWhere((x) => x.email == 'ana@test.demo');
      store.setStaffActive(acc.id, false);
      AppSession.signInDemo('ana@test.demo');
      final a = await StaffAccess.load();
      expect(a.active, isFalse);
      expect(a.can(StaffPermission.scanQr), isFalse);
    });

    test('el correo repetido se detecta y la creación queda en auditoría', () {
      expect(store.staffEmailTaken('ANA@test.demo'), isTrue);
      expect(store.audit.any((x) => x.action == 'Creó cuenta de staff'), isTrue);
    });

    tearDownAll(AppSession.clear);
  });
}
