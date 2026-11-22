import 'models.dart';

class _Ev {
  _Ev(this.id, this.name, this.description, this.startsAt, this.endsAt, this.capacity, this.paid, this.price, this.status);
  final String id;
  String name;
  String? description;
  DateTime startsAt;
  DateTime endsAt;
  int capacity;
  bool paid;
  double price;
  String status;
}

class _Tk {
  _Tk(this.id, this.eventId, this.name, this.phone, this.payment, this.status, this.checkedInAt, this.createdAt);
  final String id;
  final String eventId;
  final String name;
  final String? phone;
  String payment;
  String status;
  DateTime? checkedInAt;
  final DateTime createdAt;
}

/// Datos en memoria del panel Admin para el modo demo (sin Supabase).
class DemoAdminData {
  DemoAdminData._() {
    _seed();
  }
  static final DemoAdminData instance = DemoAdminData._();

  final List<_Ev> _events = [];
  final List<_Tk> _tickets = [];
  int _seq = 100;

  void _seed() {
    final now = DateTime.now().toUtc();
    _events.addAll([
      _Ev('ev-eclipse', 'Eclipse Party', 'Noche de house y techno con DJs invitados.', now.subtract(const Duration(hours: 2)), now.add(const Duration(hours: 6)), 200, true, 50, 'live'),
      _Ev('ev-jazz', 'Noche de Jazz', 'Jazz en vivo y coctelería.', now.add(const Duration(days: 7)), now.add(const Duration(days: 7, hours: 5)), 150, true, 40, 'active'),
      _Ev('ev-techno', 'Techno Underground', 'Sesión extendida hasta el amanecer.', now.add(const Duration(days: 10)), now.add(const Duration(days: 10, hours: 7)), 180, true, 60, 'draft'),
    ]);
    const names = [
      'Valentina Quispe', 'Rodrigo Mamani', 'Andrés Condori', 'Camila Rojas', 'Mateo Flores', 'Lucía Vargas',
      'Sofía Arce', 'Diego Ramos', 'Luciana Poma', 'Joaquín Mendoza', 'Daniela Choque', 'Sebastián Torrez',
      'Paola Gutiérrez', 'Marcelo Ticona', 'Fernanda Salazar', 'Gonzalo Apaza', 'Renata Limachi', 'Bruno Cussi',
    ];
    for (var i = 0; i < names.length; i++) {
      final used = i < 11;
      final pending = i >= 15;
      _tickets.add(_Tk('tk${_seq++}', 'ev-eclipse', names[i], '7${1000000 + i * 37211}'.substring(0, 8), pending ? 'pending' : 'paid',
          used ? 'used' : 'issued', used ? now.subtract(Duration(minutes: 5 + i * 8)) : null, now.subtract(Duration(days: 2, minutes: i))));
    }
    for (var i = 0; i < 8; i++) {
      _tickets.add(_Tk('tk${_seq++}', 'ev-jazz', names[(i * 2) % names.length], '6${2000000 + i * 51233}'.substring(0, 8), i >= 6 ? 'pending' : 'paid', 'issued', null, now.subtract(Duration(hours: i + 1))));
    }
  }

  EventItem _stats(_Ev e) {
    final ts = _tickets.where((t) => t.eventId == e.id).toList();
    final live = ts.where((t) => t.status != 'cancelled').toList();
    final hourAgo = DateTime.now().toUtc().subtract(const Duration(hours: 1));
    return EventItem(
      id: e.id,
      name: e.name,
      description: e.description,
      startsAt: e.startsAt,
      endsAt: e.endsAt,
      capacity: e.capacity,
      accessType: e.paid ? 'paid' : 'free',
      ticketPrice: e.price,
      dbStatus: e.status,
      ticketsTotal: ts.length,
      ticketsPaid: live.where((t) => t.payment == 'paid').length,
      ticketsPendingPayment: live.where((t) => t.payment == 'pending').length,
      checkins: ts.where((t) => t.status == 'used').length,
      ticketsCancelled: ts.where((t) => t.status == 'cancelled').length,
      checkinsLastHour: ts.where((t) => t.status == 'used' && t.checkedInAt != null && t.checkedInAt!.isAfter(hourAgo)).length,
    );
  }

  GuestItem _guest(_Tk t) => GuestItem(
        id: t.id,
        eventId: t.eventId,
        name: t.name,
        phone: t.phone,
        paymentStatus: t.payment,
        ticketStatus: t.status,
        checkedInAt: t.checkedInAt,
        eventName: _events.firstWhere((e) => e.id == t.eventId).name,
      );

  Future<void> _lag() => Future<void>.delayed(const Duration(milliseconds: 250));

  Future<List<EventItem>> listEvents() async {
    await _lag();
    final list = _events.map(_stats).toList()..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    return list;
  }

  Future<EventItem?> getEvent(String id) async {
    await _lag();
    for (final e in _events) {
      if (e.id == id) return _stats(e);
    }
    return null;
  }

  Future<void> createEvent({
    required String name,
    String? description,
    required DateTime startsAt,
    required DateTime endsAt,
    required int capacity,
    required bool paid,
    double price = 0,
  }) async {
    await _lag();
    _events.add(_Ev('ev-${_seq++}', name.trim(), description, startsAt, endsAt, capacity, paid, paid ? price : 0, 'draft'));
  }

  Future<void> updateEvent({
    required String id,
    required String name,
    String? description,
    required DateTime startsAt,
    required DateTime endsAt,
    required int capacity,
    required bool paid,
    double price = 0,
  }) async {
    await _lag();
    final e = _events.firstWhere((x) => x.id == id);
    if (e.status == 'finished' || e.status == 'suspended') throw Exception('event_locked');
    final sold = _tickets.where((t) => t.eventId == id && t.status != 'cancelled').length;
    if (capacity < sold) throw Exception('capacity_below_sold');
    if (sold > 0 && (paid != e.paid || (paid ? price : 0) != e.price)) throw Exception('price_locked_with_sales');
    if (!endsAt.isAfter(startsAt)) throw Exception('invalid_dates');
    e
      ..name = name.trim()
      ..description = (description == null || description.trim().isEmpty) ? null : description.trim()
      ..startsAt = startsAt
      ..endsAt = endsAt
      ..capacity = capacity
      ..paid = paid
      ..price = paid ? price : 0;
  }

  Future<void> setEventStatus(String id, String status) async {
    await _lag();
    _events.firstWhere((e) => e.id == id).status = status;
  }

  Future<List<GuestItem>> listTickets({String? eventId, String query = '', int limit = 500}) async {
    await _lag();
    final q = query.trim().toLowerCase();
    final list = _tickets
        .where((t) => (eventId == null || t.eventId == eventId) && (q.isEmpty || t.name.toLowerCase().contains(q)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.take(limit).map(_guest).toList();
  }

  Future<List<GuestItem>> recentCheckins(String eventId, {int limit = 4}) async {
    await _lag();
    final list = _tickets.where((t) => t.eventId == eventId && t.status == 'used').toList()
      ..sort((a, b) => b.checkedInAt!.compareTo(a.checkedInAt!));
    return list.take(limit).map(_guest).toList();
  }

  Future<CreatedTicket> createTicket({required String eventId, required String guestName, String? guestPhone, bool paid = false}) async {
    await _lag();
    final id = 'tk${_seq++}';
    _tickets.add(_Tk(id, eventId, guestName.trim(), guestPhone, paid ? 'paid' : 'pending', 'issued', null, DateTime.now().toUtc()));
    return CreatedTicket(ticketId: id, qrToken: 'DEMO-NO-VALIDO-$id', paymentStatus: paid ? 'paid' : 'pending');
  }
}
