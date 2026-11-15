import 'package:flutter/foundation.dart';

/// Datos 100 % simulados del prototipo. No hay backend, pagos ni envíos reales.

enum OrderStatus { awaitingPayment, verifying, approved, rejected, expired, cancelled }

enum ProtoRole { buyer, admin, verifier, superadmin }

enum DecisionResult { ok, conflict }

class TicketType {
  const TicketType({
    required this.id,
    required this.name,
    required this.price,
    required this.capacity,
    this.maxPerOrder = 6,
  });
  final String id;
  final String name;
  final double price;
  final int capacity;
  final int maxPerOrder;
}

enum EventState { active, upcoming, finished }

class Venue {
  const Venue({required this.id, required this.name, required this.zone, required this.active, required this.plan});
  final String id;
  final String name;
  final String zone;
  final bool active;
  final String plan;
}

class EventItem {
  const EventItem({
    required this.id,
    required this.name,
    required this.venueId,
    required this.date,
    required this.place,
    required this.description,
    required this.types,
    required this.state,
    required this.hue,
  });
  final String id;
  final String name;
  final String venueId;
  final DateTime date;
  final String place;
  final String description;
  final List<TicketType> types;
  final EventState state;
  final int hue; // para la portada generada (sin imágenes reales)

  double get fromPrice => types.map((t) => t.price).reduce((a, b) => a < b ? a : b);
  int get totalCapacity => types.fold(0, (s, t) => s + t.capacity);
}

class OrderLine {
  const OrderLine(this.typeId, this.qty);
  final String typeId;
  final int qty;
}

class Order {
  Order({
    required this.id,
    required this.number,
    required this.eventId,
    required this.buyerName,
    required this.ci,
    required this.phone,
    this.email,
    required this.lines,
    required this.total,
    required this.status,
    required this.createdAt,
    required this.token,
    this.declaredAt,
    this.decidedAt,
    this.decidedBy,
    this.rejectReason,
    this.ticketCodes = const [],
  });

  final String id;
  final String number;
  final String eventId;
  final String buyerName;
  final String ci;
  final String phone;
  final String? email;
  final List<OrderLine> lines;
  final double total;
  OrderStatus status;
  final DateTime createdAt;
  final String token;
  DateTime? declaredAt;
  DateTime? decidedAt;
  String? decidedBy;
  String? rejectReason;
  List<String> ticketCodes;

  int get ticketCount => lines.fold(0, (s, l) => s + l.qty);
  DateTime get expiresAt => createdAt.add(const Duration(minutes: 15));
  /// Una orden sin pagar deja de retener cupos al vencer su plazo, aunque nadie la haya cerrado.
  bool get holdsSeats =>
      (status == OrderStatus.awaitingPayment && DateTime.now().isBefore(expiresAt)) ||
      status == OrderStatus.verifying ||
      status == OrderStatus.approved;
}

class Actor {
  const Actor({required this.id, required this.name, required this.permission});
  final String id;
  final String name;
  final String permission;
}

class Employee {
  Employee({required this.id, required this.name, required this.job, this.verifier = false, this.grantedAt});
  final String id;
  final String name;
  final String job;
  bool verifier;
  DateTime? grantedAt;
}

class AuditEntry {
  const AuditEntry({
    required this.at,
    required this.actor,
    required this.permission,
    required this.action,
    required this.result,
    this.orderNumber,
    this.reason,
    this.venue,
  });
  final DateTime at;
  final String actor;
  final String permission;
  final String action;
  final String result;
  final String? orderNumber;
  final String? reason;
  final String? venue;
}

class AppNotification {
  AppNotification({required this.at, required this.text, required this.orderId});
  final DateTime at;
  final String text;
  final String orderId;
}

class ProtoStore extends ChangeNotifier {
  ProtoStore() {
    _seed();
  }

  static final ProtoStore instance = ProtoStore();

  static const bankBeneficiary = 'Dharma Club S.R.L.';
  static const admin = Actor(id: 'carla', name: 'Carla Mendoza', permission: 'Administradora del local');
  static const verifierActor = Actor(id: 'diego', name: 'Diego Ramos', permission: 'Verificador delegado de pagos');

  late final List<Venue> venues;
  late final List<EventItem> events;
  final List<Order> orders = [];
  final List<AuditEntry> audit = [];
  final List<AppNotification> notifications = [];
  late final List<Employee> employees;
  final List<AuditEntry> platformLog = [];
  int _seq = 1046;

  DateTime get now => DateTime.now();

  void _seed() {
    final n = DateTime.now();
    DateTime day(int d, int h) => DateTime(n.year, n.month, n.day, h).add(Duration(days: d));

    venues = const [
      Venue(id: 'v1', name: 'Dharma Club', zone: 'Zona Sur', active: true, plan: 'Pro'),
      Venue(id: 'v2', name: 'Sala Akelarre', zone: 'Sopocachi', active: true, plan: 'Starter'),
      Venue(id: 'v3', name: 'Cielo Rooftop', zone: 'Centro', active: true, plan: 'Local Premium'),
      Venue(id: 'v4', name: 'Lúmen Lounge', zone: 'Calacoto', active: false, plan: 'Starter'),
    ];

    events = [
      EventItem(
        id: 'e1',
        name: 'Eclipse Party',
        venueId: 'v1',
        date: day(3, 22),
        place: 'Dharma Club · Zona Sur',
        description: 'Noche de house y techno con DJs invitados. Apertura de puertas a las 22:00.',
        types: const [
          TicketType(id: 'e1g', name: 'General', price: 50, capacity: 300),
          TicketType(id: 'e1v', name: 'VIP', price: 120, capacity: 60, maxPerOrder: 4),
        ],
        state: EventState.active,
        hue: 150,
      ),
      EventItem(
        id: 'e2',
        name: 'Noche Retro 90s',
        venueId: 'v2',
        date: day(7, 21),
        place: 'Sala Akelarre · Sopocachi',
        description: 'Un viaje a los 90: pop, rock y cumbia con ambientación temática.',
        types: const [TicketType(id: 'e2g', name: 'General', price: 40, capacity: 200)],
        state: EventState.active,
        hue: 290,
      ),
      EventItem(
        id: 'e3',
        name: 'Techno Underground',
        venueId: 'v1',
        date: day(10, 23),
        place: 'Dharma Club · Zona Sur',
        description: 'Sesión extendida hasta el amanecer con line-up local.',
        types: const [
          TicketType(id: 'e3g', name: 'Preventa', price: 60, capacity: 120),
          TicketType(id: 'e3v', name: 'VIP', price: 150, capacity: 40, maxPerOrder: 4),
        ],
        state: EventState.upcoming,
        hue: 210,
      ),
      EventItem(
        id: 'e4',
        name: 'Sunset Rooftop',
        venueId: 'v3',
        date: day(14, 18),
        place: 'Cielo Rooftop · Centro',
        description: 'Atardecer con vista a la ciudad, música lounge y coctelería.',
        types: const [TicketType(id: 'e4g', name: 'General', price: 70, capacity: 150)],
        state: EventState.upcoming,
        hue: 30,
      ),
      EventItem(
        id: 'e5',
        name: 'Halloween Bash',
        venueId: 'v1',
        date: day(-15, 22),
        place: 'Dharma Club · Zona Sur',
        description: 'Evento finalizado.',
        types: const [TicketType(id: 'e5g', name: 'General', price: 50, capacity: 300)],
        state: EventState.finished,
        hue: 20,
      ),
    ];

    employees = [
      Employee(id: 'diego', name: 'Diego Ramos', job: 'Encargado de barra', verifier: true, grantedAt: n.subtract(const Duration(days: 9))),
      Employee(id: 'lucia', name: 'Lucía Vargas', job: 'Anfitriona'),
      Employee(id: 'marco', name: 'Marco Limachi', job: 'Staff de puerta'),
      Employee(id: 'sofia', name: 'Sofía Arce', job: 'Relaciones públicas'),
    ];

    Order mk(String num, String ev, String name, String ci, String phone, List<OrderLine> lines, OrderStatus st,
        {int declaredMinAgo = 0, String? email}) {
      final e = events.firstWhere((x) => x.id == ev);
      final total = lines.fold<double>(0, (s, l) => s + l.qty * e.types.firstWhere((t) => t.id == l.typeId).price);
      final declared = n.subtract(Duration(minutes: declaredMinAgo));
      return Order(
        id: 'o$num',
        number: 'CHK-$num',
        eventId: ev,
        buyerName: name,
        ci: ci,
        phone: phone,
        email: email,
        lines: lines,
        total: total,
        status: st,
        createdAt: declared.subtract(const Duration(minutes: 4)),
        declaredAt: st == OrderStatus.awaitingPayment ? null : declared,
        token: 'tk$num${num.hashCode.abs() % 997}',
      );
    }

    final o42 = mk('1042', 'e1', 'Valentina Quispe', '8123456 LP', '7•• ••412', const [OrderLine('e1g', 2)], OrderStatus.verifying, declaredMinAgo: 42);
    final o43 = mk('1043', 'e1', 'Rodrigo Mamani', '9345671 LP', '6•• ••087', const [OrderLine('e1v', 1)], OrderStatus.verifying, declaredMinAgo: 8, email: 'rodrigo@mail.com');
    final o44 = mk('1044', 'e2', 'Camila Rojas', '7456123 CB', '7•• ••230', const [OrderLine('e2g', 4)], OrderStatus.verifying, declaredMinAgo: 190);
    final o45 = mk('1045', 'e1', 'Andrés Condori', '6789012 LP', '7•• ••905', const [OrderLine('e1v', 2)], OrderStatus.approved, declaredMinAgo: 300);
    o45
      ..decidedAt = n.subtract(const Duration(minutes: 280))
      ..decidedBy = 'Carla Mendoza'
      ..ticketCodes = ['DEMO-1045-1', 'DEMO-1045-2'];
    final o46 = mk('1046', 'e1', 'Mateo Flores', '5567890 LP', '6•• ••561', const [OrderLine('e1g', 1)], OrderStatus.rejected, declaredMinAgo: 600);
    o46
      ..decidedAt = n.subtract(const Duration(minutes: 560))
      ..decidedBy = 'Diego Ramos'
      ..rejectReason = 'No se encontró el depósito en la cuenta del local.';
    orders.addAll([o42, o43, o44, o45, o46]);

    for (final o in [o42, o43, o44]) {
      notifications.add(AppNotification(
        at: o.declaredAt!,
        text: 'Un comprador informó un pago de Bs. ${o.total.toStringAsFixed(0)}. Revisa tu cuenta bancaria para confirmar el depósito.',
        orderId: o.id,
      ));
    }
    notifications.sort((a, b) => b.at.compareTo(a.at));

    audit.addAll([
      AuditEntry(at: o45.decidedAt!, actor: 'Carla Mendoza', permission: 'Administradora del local', action: 'Aprobó pago', result: 'Aprobado · 2 QR generados', orderNumber: o45.number),
      AuditEntry(at: o46.decidedAt!, actor: 'Diego Ramos', permission: 'Verificador delegado de pagos', action: 'Rechazó pago', result: 'Rechazado definitivamente', orderNumber: o46.number, reason: o46.rejectReason),
      AuditEntry(at: n.subtract(const Duration(days: 9)), actor: 'Carla Mendoza', permission: 'Administradora del local', action: 'Concedió permiso de verificación bancaria', result: 'Permiso activo', reason: 'Empleado: Diego Ramos'),
    ]);

    platformLog.addAll([
      AuditEntry(at: n.subtract(const Duration(hours: 2)), actor: 'Sistema', permission: 'Plataforma', action: 'Evento publicado', result: 'Eclipse Party', venue: 'Dharma Club'),
      AuditEntry(at: n.subtract(const Duration(days: 1)), actor: 'Equipo CHECK', permission: 'Superadministrador', action: 'Local dado de alta', result: 'Cielo Rooftop · plan Local Premium', venue: 'Cielo Rooftop'),
      AuditEntry(at: n.subtract(const Duration(days: 3)), actor: 'Equipo CHECK', permission: 'Superadministrador', action: 'Local marcado inactivo (demo)', result: 'Lúmen Lounge', venue: 'Lúmen Lounge'),
    ]);
  }

  // ---------------- consultas ----------------
  EventItem eventById(String id) => events.firstWhere((e) => e.id == id);
  Venue venueById(String id) => venues.firstWhere((v) => v.id == id);
  Order? orderById(String id) {
    for (final o in orders) {
      if (o.id == id) return o;
    }
    return null;
  }

  Order? orderByToken(String t) {
    final q = t.trim().toLowerCase();
    if (q.isEmpty) return null;
    for (final o in orders) {
      if (o.token.toLowerCase() == q || o.number.toLowerCase() == q) return o;
    }
    return null;
  }

  int sold(String typeId) => orders.where((o) => o.holdsSeats).fold(0, (s, o) {
        return s + o.lines.where((l) => l.typeId == typeId).fold(0, (a, l) => a + l.qty);
      });

  int remaining(TicketType t) {
    final r = t.capacity - sold(t.id);
    return r < 0 ? 0 : r;
  }

  List<Order> get pending => orders.where((o) => o.status == OrderStatus.verifying).toList()
    ..sort((a, b) => a.declaredAt!.compareTo(b.declaredAt!));

  int get unreadNotifications => notifications.length;

  int ticketsSold(String eventId) => orders
      .where((o) => o.eventId == eventId && o.status == OrderStatus.approved)
      .fold(0, (s, o) => s + o.ticketCount);

  bool verifierEnabled(String employeeId) => employees.firstWhere((e) => e.id == employeeId).verifier;

  int verificationsBy(String name) =>
      audit.where((a) => a.actor == name && (a.action == 'Aprobó pago' || a.action == 'Rechazó pago')).length;

  // ---------------- comprador ----------------
  Order createOrder({
    required String eventId,
    required Map<String, int> qty,
    required String name,
    required String ci,
    required String phone,
    String? email,
  }) {
    final e = eventById(eventId);
    final lines = <OrderLine>[];
    var total = 0.0;
    qty.forEach((id, q) {
      if (q > 0) {
        lines.add(OrderLine(id, q));
        total += q * e.types.firstWhere((t) => t.id == id).price;
      }
    });
    _seq++;
    final o = Order(
      id: 'o$_seq',
      number: 'CHK-$_seq',
      eventId: eventId,
      buyerName: name,
      ci: ci,
      phone: phone,
      email: (email == null || email.trim().isEmpty) ? null : email.trim(),
      lines: lines,
      total: total,
      status: OrderStatus.awaitingPayment,
      createdAt: DateTime.now(),
      token: 'tk$_seq${DateTime.now().millisecondsSinceEpoch % 9973}',
    );
    orders.add(o);
    notifyListeners();
    return o;
  }

  void declarePaid(String id) {
    final o = orderById(id);
    if (o == null || o.status != OrderStatus.awaitingPayment) return;
    o.status = OrderStatus.verifying;
    o.declaredAt = DateTime.now();
    notifications.insert(
      0,
      AppNotification(
        at: o.declaredAt!,
        text: 'Un comprador informó un pago de Bs. ${o.total.toStringAsFixed(0)}. Revisa tu cuenta bancaria para confirmar el depósito.',
        orderId: o.id,
      ),
    );
    notifyListeners();
  }

  void cancelOrder(String id) {
    final o = orderById(id);
    if (o == null || o.status != OrderStatus.awaitingPayment) return;
    o.status = OrderStatus.cancelled;
    notifyListeners();
  }

  void expireIfNeeded(String id) {
    final o = orderById(id);
    if (o != null && o.status == OrderStatus.awaitingPayment && DateTime.now().isAfter(o.expiresAt)) {
      o.status = OrderStatus.expired;
      notifyListeners();
    }
  }

  // ---------------- decisiones (admin / verificador) ----------------
  DecisionResult approve(String id, Actor actor) {
    final o = orderById(id)!;
    if (o.status != OrderStatus.verifying) {
      audit.insert(0, AuditEntry(at: now, actor: actor.name, permission: actor.permission, action: 'Intento de aprobación bloqueado', result: 'Conflicto: la orden ya tenía una decisión', orderNumber: o.number));
      notifyListeners();
      return DecisionResult.conflict;
    }
    o.status = OrderStatus.approved;
    o.decidedAt = now;
    o.decidedBy = actor.name;
    o.ticketCodes = List.generate(o.ticketCount, (i) => 'DEMO-${o.number.substring(4)}-${i + 1}');
    audit.insert(0, AuditEntry(at: now, actor: actor.name, permission: actor.permission, action: 'Aprobó pago', result: 'Aprobado · ${o.ticketCount} QR generados', orderNumber: o.number));
    notifyListeners();
    return DecisionResult.ok;
  }

  DecisionResult reject(String id, Actor actor, String reason) {
    final o = orderById(id)!;
    if (o.status != OrderStatus.verifying) {
      audit.insert(0, AuditEntry(at: now, actor: actor.name, permission: actor.permission, action: 'Intento de rechazo bloqueado', result: 'Conflicto: la orden ya tenía una decisión', orderNumber: o.number));
      notifyListeners();
      return DecisionResult.conflict;
    }
    o.status = OrderStatus.rejected;
    o.decidedAt = now;
    o.decidedBy = actor.name;
    o.rejectReason = reason;
    audit.insert(0, AuditEntry(at: now, actor: actor.name, permission: actor.permission, action: 'Rechazó pago', result: 'Rechazado definitivamente · cupos liberados', orderNumber: o.number, reason: reason));
    notifyListeners();
    return DecisionResult.ok;
  }

  /// Demo: otro verificador se adelanta y aprueba la misma orden.
  void simulateOtherVerifier(String id) {
    final o = orderById(id);
    if (o == null || o.status != OrderStatus.verifying) return;
    o.status = OrderStatus.approved;
    o.decidedAt = now;
    o.decidedBy = 'Otro verificador';
    o.ticketCodes = List.generate(o.ticketCount, (i) => 'DEMO-${o.number.substring(4)}-${i + 1}');
    audit.insert(0, AuditEntry(at: now, actor: 'Otro verificador', permission: 'Verificador delegado de pagos', action: 'Aprobó pago', result: 'Aprobado · ${o.ticketCount} QR generados', orderNumber: o.number));
    notifyListeners();
  }

  // ---------------- delegación ----------------
  void setVerifier(String employeeId, bool enabled) {
    final e = employees.firstWhere((x) => x.id == employeeId);
    e.verifier = enabled;
    e.grantedAt = enabled ? now : null;
    audit.insert(
      0,
      AuditEntry(
        at: now,
        actor: admin.name,
        permission: admin.permission,
        action: enabled ? 'Concedió permiso de verificación bancaria' : 'Revocó permiso de verificación bancaria',
        result: enabled ? 'Permiso activo' : 'Permiso revocado',
        reason: 'Empleado: ${e.name}',
      ),
    );
    notifyListeners();
  }
}
