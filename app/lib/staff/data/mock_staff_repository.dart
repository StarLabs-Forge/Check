import 'staff_models.dart';
import 'staff_repository.dart';

/// Implementación en memoria para recorrer el flujo sin Supabase.
///
/// Tokens QR de prueba: `VALID` (ingreso nuevo), `USED` (ya registrado),
/// `OFFLINE` (sin conexión), cualquier otro texto → denegado.
class MockStaffRepository implements StaffRepository {
  MockStaffRepository() {
    final now = DateTime.now();
    _events = [
      StaffEvent(
        id: 'ev-eclipse',
        name: 'Eclipse Party',
        startsAt: DateTime(now.year, now.month, now.day, 22),
        capacity: 200,
        checkins: 143,
      ),
    ];

    DateTime today(int h, int m) => DateTime(now.year, now.month, now.day, h, m);
    _guests = [
      StaffGuest(id: 'g1', eventId: 'ev-eclipse', name: 'Valentina Quispe', phone: '+591 7•• ••412'),
      StaffGuest(
          id: 'g2', eventId: 'ev-eclipse', name: 'Rodrigo Mamani', phone: '+591 6•• ••087', checkedInAt: today(21, 41)),
      StaffGuest(id: 'g3', eventId: 'ev-eclipse', name: 'Andrés Condori', phone: '+591 7•• ••905'),
      StaffGuest(id: 'g4', eventId: 'ev-eclipse', name: 'Camila Rojas', phone: '+591 7•• ••230'),
      StaffGuest(
          id: 'g5', eventId: 'ev-eclipse', name: 'Mateo Flores', phone: '+591 6•• ••561', checkedInAt: today(21, 12)),
      StaffGuest(id: 'g6', eventId: 'ev-eclipse', name: 'Lucía Vargas', phone: '+591 7•• ••778'),
    ];
  }

  late List<StaffEvent> _events;
  late List<StaffGuest> _guests;

  static const _latency = Duration(milliseconds: 450);

  @override
  Future<void> signOut() async {}

  bool _offline = false;

  /// En el mock, tras simular una caída (token `OFFLINE`) la primera
  /// comprobación vuelve a "en línea" para poder probar "Reintentar".
  @override
  Future<bool> isOnline() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (_offline) {
      _offline = false;
      return true;
    }
    return true;
  }

  @override
  Future<List<StaffEvent>> assignedEvents() async {
    await Future<void>.delayed(_latency);
    return List.unmodifiable(_events);
  }

  StaffEvent _event(String id) => _events.firstWhere((e) => e.id == id);

  ScanOutcome _registerEntry(StaffGuest guest) {
    final at = DateTime.now();
    final i = _guests.indexWhere((g) => g.id == guest.id);
    _guests[i] = guest.copyWith(checkedInAt: at);
    final ev = _event(guest.eventId);
    final updated = ev.copyWith(checkins: ev.checkins + 1);
    _events[_events.indexWhere((e) => e.id == ev.id)] = updated;
    return ScanOutcome.success(
      guestName: guest.name,
      checkedInAt: at,
      checkins: updated.checkins,
      capacity: updated.capacity,
    );
  }

  @override
  Future<ScanOutcome> scanQr({required String eventId, required String token}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final pool = _guests.where((g) => g.eventId == eventId);
    switch (token) {
      case 'OFFLINE':
        _offline = true;
        throw Exception('network unreachable');
      case 'VALID':
        final next = pool.where((g) => !g.hasEntered);
        if (next.isEmpty) return const ScanOutcome.denied();
        return _registerEntry(next.first);
      case 'USED':
        final used = pool.where((g) => g.hasEntered);
        if (used.isEmpty) return const ScanOutcome.denied();
        final g = used.first;
        return ScanOutcome.alreadyRegistered(guestName: g.name, checkedInAt: g.checkedInAt!);
      default:
        return const ScanOutcome.denied();
    }
  }

}
