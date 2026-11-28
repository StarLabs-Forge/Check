import 'staff_models.dart';
import 'staff_repository.dart';

/// Implementación en memoria para recorrer el flujo sin Supabase.
///
/// Tokens QR de prueba: `VALID` (ingreso nuevo), `USED` (ya registrado),
/// `OFFLINE` (sin conexión), cualquier otro texto → denegado.
class MockStaffRepository implements StaffRepository {
  MockStaffRepository() : this._(null);

  /// Invitados de ejemplo sobre un evento real, para simular el escáner sin
  /// tocar la base: nada de lo que haga se guarda.
  MockStaffRepository.forEvent(StaffEvent event) : this._(event);

  MockStaffRepository._(StaffEvent? only) {
    final now = DateTime.now();
    final eventId = only?.id ?? 'ev-eclipse';
    _events = [
      only ??
          StaffEvent(
            id: eventId,
            name: 'Eclipse Party',
            startsAt: DateTime(now.year, now.month, now.day, 22),
            capacity: 200,
            checkins: 143,
          ),
    ];

    DateTime today(int h, int m) => DateTime(now.year, now.month, now.day, h, m);
    _guests = [
      StaffGuest(id: 'g1', eventId: eventId, name: 'Valentina Quispe', phone: '+591 7•• ••412'),
      StaffGuest(id: 'g2', eventId: eventId, name: 'Rodrigo Mamani', phone: '+591 6•• ••087', checkedInAt: today(21, 41)),
      StaffGuest(id: 'g3', eventId: eventId, name: 'Andrés Condori', phone: '+591 7•• ••905'),
      StaffGuest(id: 'g4', eventId: eventId, name: 'Camila Rojas', phone: '+591 7•• ••230'),
      StaffGuest(id: 'g5', eventId: eventId, name: 'Mateo Flores', phone: '+591 6•• ••561', checkedInAt: today(21, 12)),
      StaffGuest(id: 'g6', eventId: eventId, name: 'Lucía Vargas', phone: '+591 7•• ••778'),
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

  /// Cuando ya entraron todos los de ejemplo se agrega otro, para que la
  /// simulación se pueda repetir sin límite.
  StaffGuest _extraGuest(String eventId) {
    const names = ['Daniela Gutiérrez', 'Sebastián Choque', 'Mariana Suárez', 'Joaquín Mendoza'];
    final n = _guests.length;
    final guest = StaffGuest(id: 'g${n + 1}', eventId: eventId, name: names[n % names.length], phone: '+591 7•• ••000');
    _guests.add(guest);
    return guest;
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
        return _registerEntry(next.isEmpty ? _extraGuest(eventId) : next.first);
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
