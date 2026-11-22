import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/demo_mode.dart';
import '../../services/app_session.dart';
import '../../services/errors.dart';

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

/// Error de negocio con mensaje listo para mostrar.
class StoreException implements Exception {
  const StoreException(this.message);
  final String message;
  @override
  String toString() => message;
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
    this.remote = false,
    this.bank,
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

  /// `true` si el pedido vive en Supabase (no es de la demo).
  final bool remote;

  /// Datos bancarios del local (solo mientras se espera o verifica el pago).
  Map<String, dynamic>? bank;

  /// Código que el comprador guarda: `<id>.<token>` en pedidos reales.
  String get code => remote ? '$id.$token' : token;

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

/// Permisos que el administrador puede asignar a una cuenta de staff.
enum StaffPermission {
  scanQr('Escanear QR en puerta', 'Validar entradas en el acceso del evento.'),
  verifyPayments('Verificar pagos', 'Aprobar o rechazar pagos declarados.'),
  viewGuests('Ver lista de invitados', 'Consultar entradas y asistentes.'),
  createTickets('Emitir entradas', 'Crear entradas manuales para invitados.'),
  viewEvents('Ver eventos', 'Consultar los eventos del local.');

  const StaffPermission(this.label, this.description);
  final String label;
  final String description;
}

/// Cuenta de acceso del personal creada por el administrador.
class StaffAccount {
  StaffAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.job,
    required this.permissions,
    this.active = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
  final String id;
  String name;
  final String email;
  String job;
  Set<StaffPermission> permissions;
  bool active;
  final DateTime createdAt;
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
    if (kDemo) {
      _seed();
    } else {
      AppSession.profile.addListener(_onProfile);
      _onProfile();
    }
  }

  Timer? _adminTimer;

  /// Al iniciar/cerrar sesión: carga los datos del panel y los mantiene al día.
  void _onProfile() {
    final me = AppSession.profile.value;
    _adminTimer?.cancel();
    _adminTimer = null;
    if (me == null || me.role == 'super_admin') {
      orders.removeWhere((o) => o.token.isEmpty);
      audit.clear();
      notifications.clear();
      employees = [];
      _verifierAllowed = false;
      notifyListeners();
      return;
    }
    loadAdmin();
    _adminTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!adminLoading && AppSession.profile.value != null) loadAdmin();
    });
  }

  /// `true` cuando los datos vienen de Supabase (todo lo que no es DEMO).
  bool get live => !kDemo;
  SupabaseClient get _db => Supabase.instance.client;

  static final ProtoStore instance = ProtoStore();

  static const bankBeneficiary = 'Dharma Club S.R.L.';
  /// Administrador del local: usa el perfil real de la sesión si existe.
  static Actor get admin => Actor(
        id: 'admin',
        name: AppSession.profile.value?.fullName ?? 'Carla Mendoza',
        permission: 'Administrador del local',
      );
  static Actor get verifierActor => kDemo
      ? const Actor(id: 'diego', name: 'Diego Ramos', permission: 'Verificador delegado de pagos')
      : Actor(
          id: AppSession.profile.value?.id ?? 'verificador',
          name: AppSession.profile.value?.fullName ?? 'Verificador',
          permission: 'Verificador delegado de pagos',
        );

  List<Venue> venues = [];
  List<EventItem> events = [];
  final List<Order> orders = [];
  final List<AuditEntry> audit = [];
  final List<AppNotification> notifications = [];
  List<Employee> employees = [];
  final List<AuditEntry> platformLog = [];
  final List<StaffAccount> staffAccounts = [];
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
  EventItem eventById(String id) {
    for (final e in events) {
      if (e.id == id) return e;
    }
    return _orderEvents[id] ?? events.firstWhere((e) => e.id == id);
  }

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

  /// Cupos libres según el servidor (modo real).
  final Map<String, int> _avail = {};

  /// Eventos conocidos solo por un pedido (p. ej. ya finalizados).
  final Map<String, EventItem> _orderEvents = {};

  int sold(String typeId) => orders.where((o) => o.holdsSeats).fold(0, (s, o) {
        return s + o.lines.where((l) => l.typeId == typeId).fold(0, (a, l) => a + l.qty);
      });

  int remaining(TicketType t) {
    if (live) return _avail[t.id] ?? t.capacity;
    final r = t.capacity - sold(t.id);
    return r < 0 ? 0 : r;
  }

  List<Order> get pending => orders.where((o) => o.status == OrderStatus.verifying).toList()
    ..sort((a, b) => a.declaredAt!.compareTo(b.declaredAt!));

  int get unreadNotifications => notifications.length;

  int ticketsSold(String eventId) => orders
      .where((o) => o.eventId == eventId && o.status == OrderStatus.approved)
      .fold(0, (s, o) => s + o.ticketCount);

  bool _verifierAllowed = false;

  bool verifierEnabled(String employeeId) {
    if (live) return _verifierAllowed;
    return employees.firstWhere((e) => e.id == employeeId).verifier;
  }

  int verificationsBy(String name) =>
      audit.where((a) => a.actor == name && (a.action == 'Aprobó pago' || a.action == 'Rechazó pago')).length;

  // ---------------- comprador ----------------
  Future<Order> createOrder({
    required String eventId,
    required Map<String, int> qty,
    required String name,
    required String ci,
    required String phone,
    String? email,
  }) async {
    if (live) return _createRemote(eventId: eventId, qty: qty, name: name, ci: ci, phone: phone, email: email);
    return _createLocal(eventId: eventId, qty: qty, name: name, ci: ci, phone: phone, email: email);
  }

  Order _createLocal({
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

  Future<void> declarePaid(String id) async {
    final o = orderById(id);
    if (o != null && o.remote) {
      try {
        await _db.rpc('declare_payment', params: {'p_order_id': o.id, 'p_token': o.token});
      } catch (_) {
        // Si venció o ya cambió, el refresco de abajo muestra el estado real.
      }
      await refreshOrder(id);
      return;
    }
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

  Future<void> cancelOrder(String id) async {
    final o = orderById(id);
    if (o != null && o.remote) {
      try {
        await _db.rpc('cancel_order', params: {'p_order_id': o.id, 'p_token': o.token});
      } catch (_) {}
      await refreshOrder(id);
      return;
    }
    if (o == null || o.status != OrderStatus.awaitingPayment) return;
    o.status = OrderStatus.cancelled;
    notifyListeners();
  }

  void expireIfNeeded(String id) {
    final o = orderById(id);
    if (o != null && o.status == OrderStatus.awaitingPayment && DateTime.now().isAfter(o.expiresAt)) {
      if (o.remote) {
        refreshOrder(id); // el servidor es quien decide el vencimiento
        return;
      }
      o.status = OrderStatus.expired;
      notifyListeners();
    }
  }

  // ---------------- decisiones (admin / verificador) ----------------
  Future<DecisionResult> approve(String id, Actor actor) async {
    if (live) return _decideRemote(id, approve: true);
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

  Future<DecisionResult> reject(String id, Actor actor, String reason) async {
    if (live) return _decideRemote(id, approve: false, reason: reason);
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

  // ---------------- cuentas de staff ----------------
  void _logStaff(String action, StaffAccount a, String result) {
    audit.insert(0, AuditEntry(at: now, actor: admin.name, permission: admin.permission, action: action, result: result, reason: 'Cuenta: ${a.email}'));
  }

  bool staffEmailTaken(String email) =>
      staffAccounts.any((a) => a.email.toLowerCase() == email.trim().toLowerCase());

  StaffAccount createStaffAccount({
    required String name,
    required String email,
    required String job,
    required Set<StaffPermission> permissions,
  }) {
    final a = StaffAccount(
      id: 'st${staffAccounts.length + 1}-${now.millisecondsSinceEpoch}',
      name: name.trim(),
      email: email.trim().toLowerCase(),
      job: job.trim(),
      permissions: {...permissions},
    );
    staffAccounts.insert(0, a);
    _logStaff('Creó cuenta de staff', a, '${a.permissions.length} permisos asignados');
    notifyListeners();
    return a;
  }

  void updateStaffPermissions(String id, Set<StaffPermission> permissions) {
    final a = staffAccounts.firstWhere((x) => x.id == id);
    a.permissions = {...permissions};
    _logStaff('Cambió permisos de staff', a, '${a.permissions.length} permisos activos');
    notifyListeners();
  }

  void setStaffActive(String id, bool active) {
    final a = staffAccounts.firstWhere((x) => x.id == id);
    a.active = active;
    _logStaff(active ? 'Reactivó cuenta de staff' : 'Desactivó cuenta de staff', a, active ? 'Cuenta activa' : 'Acceso bloqueado');
    notifyListeners();
  }

  void deleteStaffAccount(String id) {
    final a = staffAccounts.firstWhere((x) => x.id == id);
    staffAccounts.remove(a);
    _logStaff('Eliminó cuenta de staff', a, 'Cuenta eliminada');
    notifyListeners();
  }

  // ---------------- delegación ----------------
  Future<void> setVerifier(String employeeId, bool enabled) async {
    if (live) {
      await _db.rpc(enabled ? 'grant_payment_verifier' : 'revoke_payment_verifier', params: {'p_verifier_id': employeeId});
      await loadAdmin();
      return;
    }
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

  // =====================================================================
  //  MODO REAL (Supabase)
  // =====================================================================

  static String _msg(Object e) {
    if (e is PostgrestException) {
      final m = e.message;
      const map = {
        'invalid_buyer_name': 'Escribe tu nombre completo.',
        'invalid_buyer_ci': 'El CI no es válido.',
        'invalid_buyer_phone': 'El celular no es válido.',
        'invalid_buyer_email': 'El correo no es válido.',
        'invalid_lines': 'Elige al menos una entrada.',
        'invalid_quantity': 'La cantidad de entradas no es válida.',
        'invalid_ticket_type': 'Ese tipo de entrada ya no está disponible.',
        'event_not_available': 'Este evento ya no está a la venta.',
        'sold_out': 'Se agotaron las entradas que elegiste. Actualiza e intenta de nuevo.',
        'too_many_open_orders': 'Ya tienes varios pedidos sin pagar. Paga o cancela alguno antes de crear otro.',
        'venue_payment_not_configured': 'Este local todavía no configuró su cuenta para recibir pagos.',
        'plan_limit_tickets': 'Este evento alcanzó su límite de entradas.',
        'order_total_zero': 'El total del pedido no es válido.',
        'order_expired': 'El tiempo para pagar terminó.',
        'not_found': 'No encontramos ese pedido.',
        'reason_required': 'Escribe el motivo del rechazo.',
        'not_your_staff': 'Esa persona todavía no se unió a un evento de tu local.',
      };
      for (final en in map.entries) {
        if (m.contains(en.key)) return en.value;
      }
    }
    return friendlyError(e);
  }

  static DateTime _dt(dynamic v) => DateTime.parse(v as String).toLocal();
  static DateTime? _dtn(dynamic v) => v == null ? null : _dt(v);

  static OrderStatus _status(String s) => switch (s) {
        'awaiting_payment' => OrderStatus.awaitingPayment,
        'verifying' => OrderStatus.verifying,
        'approved' => OrderStatus.approved,
        'rejected' => OrderStatus.rejected,
        'expired' => OrderStatus.expired,
        _ => OrderStatus.cancelled,
      };

  EventItem _eventFromJson(Map<String, dynamic> j) {
    final venueName = (j['venue_name'] as String?) ?? 'Local';
    final zone = (j['venue_zone'] as String?) ?? '';
    final start = _dt(j['starts_at']);
    final status = j['status'] as String? ?? 'active';
    final soon = start.difference(DateTime.now()).inDays < 7;
    final types = <TicketType>[];
    for (final t in ((j['types'] as List?) ?? const [])) {
      final m = Map<String, dynamic>.from(t as Map);
      final id = m['id'] as String;
      _avail[id] = (m['available'] as num?)?.toInt() ?? (m['capacity'] as num).toInt();
      types.add(TicketType(
        id: id,
        name: m['name'] as String,
        price: (m['price'] as num).toDouble(),
        capacity: (m['capacity'] as num).toInt(),
        maxPerOrder: (m['max_per_order'] as num?)?.toInt() ?? 6,
      ));
    }
    return EventItem(
      id: j['id'] as String,
      name: j['name'] as String,
      venueId: venueName,
      date: start,
      place: zone.isEmpty ? venueName : '$venueName · $zone',
      description: (j['description'] as String?) ?? '',
      types: types,
      state: (status == 'live' || soon) ? EventState.active : EventState.upcoming,
      hue: (j['id'] as String).hashCode.abs() % 360,
    );
  }

  bool catalogLoading = false;
  bool catalogLoaded = false;
  String? catalogError;

  /// Catálogo público (sin sesión): eventos a la venta con cupos libres.
  Future<void> loadCatalog() async {
    if (!live) return;
    catalogLoading = true;
    catalogError = null;
    notifyListeners();
    try {
      final res = await _db.rpc('public_events');
      final evs = <EventItem>[];
      final vs = <String, Venue>{};
      for (final raw in (res as List)) {
        final m = Map<String, dynamic>.from(raw as Map);
        final e = _eventFromJson(m);
        evs.add(e);
        vs.putIfAbsent(e.venueId, () => Venue(id: e.venueId, name: e.venueId, zone: (m['venue_zone'] as String?) ?? '', active: true, plan: ''));
      }
      events = evs;
      venues = vs.values.toList();
    } catch (e) {
      catalogError = _msg(e);
    }
    catalogLoading = false;
    catalogLoaded = true;
    notifyListeners();
  }

  Future<Order> _createRemote({
    required String eventId,
    required Map<String, int> qty,
    required String name,
    required String ci,
    required String phone,
    String? email,
  }) async {
    try {
      final lines = [
        for (final en in qty.entries)
          if (en.value > 0) {'type_id': en.key, 'qty': en.value},
      ];
      final res = Map<String, dynamic>.from(await _db.rpc('create_order', params: {
        'p_event_id': eventId,
        'p_buyer_name': name,
        'p_buyer_ci': ci,
        'p_buyer_phone': phone,
        'p_buyer_email': (email == null || email.trim().isEmpty) ? null : email.trim(),
        'p_lines': lines,
      }) as Map);
      final expires = _dt(res['expires_at']);
      final o = Order(
        id: res['order_id'] as String,
        number: res['number'] as String,
        eventId: eventId,
        buyerName: name,
        ci: ci,
        phone: phone,
        email: (email == null || email.trim().isEmpty) ? null : email.trim(),
        lines: [for (final l in lines) OrderLine(l['type_id'] as String, l['qty'] as int)],
        total: (res['total'] as num).toDouble(),
        status: OrderStatus.awaitingPayment,
        createdAt: expires.subtract(const Duration(minutes: 15)),
        token: res['token'] as String,
        remote: true,
      );
      orders.add(o);
      final ev = events.where((e) => e.id == eventId);
      if (ev.isNotEmpty) _orderEvents[eventId] = ev.first; // sigue resolviéndose aunque salga del catálogo
      notifyListeners();
      await refreshOrder(o.id); // trae los datos bancarios del local
      return o;
    } catch (e) {
      loadCatalog(); // los cupos pudieron cambiar
      throw StoreException(_msg(e));
    }
  }

  /// Vuelve a pedir el estado del pedido al servidor (con su token).
  Future<void> refreshOrder(String id) async {
    final o = orderById(id);
    if (o == null || !o.remote) return;
    try {
      final res = Map<String, dynamic>.from(await _db.rpc('get_order', params: {'p_order_id': o.id, 'p_token': o.token}) as Map);
      _applyOrderJson(o, res);
      notifyListeners();
    } catch (_) {
      // Sin red: se mantiene el último estado conocido.
    }
  }

  void _applyOrderJson(Order o, Map<String, dynamic> res) {
    final j = Map<String, dynamic>.from(res['order'] as Map);
    o.status = _status(j['status'] as String);
    o.declaredAt = _dtn(j['declared_at']);
    o.decidedAt = _dtn(j['decided_at']);
    o.rejectReason = j['reject_reason'] as String?;
    o.bank = res['bank'] == null ? null : Map<String, dynamic>.from(res['bank'] as Map);
    o.ticketCodes = [
      for (final t in ((res['tickets'] as List?) ?? const [])) (t as Map)['qr_token'] as String,
    ];
  }

  /// Abre un pedido a partir de su código `<id>.<token>` (consulta privada).
  Future<Order?> loadOrderByCode(String raw) async {
    final code = raw.trim();
    final cut = code.lastIndexOf('/');
    final clean = cut >= 0 ? code.substring(cut + 1) : code;
    final dot = clean.indexOf('.');
    if (dot <= 0 || dot == clean.length - 1) return null;
    final id = clean.substring(0, dot);
    final token = clean.substring(dot + 1);
    final known = orderById(id);
    if (known != null) {
      await refreshOrder(id);
      return known;
    }
    try {
      final res = Map<String, dynamic>.from(await _db.rpc('get_order', params: {'p_order_id': id, 'p_token': token}) as Map);
      final j = Map<String, dynamic>.from(res['order'] as Map);
      final ev = Map<String, dynamic>.from(res['event'] as Map);
      final venue = Map<String, dynamic>.from(res['venue'] as Map);
      final lines = <OrderLine>[];
      final types = <TicketType>[];
      var i = 0;
      for (final raw in (res['lines'] as List)) {
        final l = Map<String, dynamic>.from(raw as Map);
        final tid = (l['type_id'] as String?) ?? 'linea$i';
        i++;
        final qty = (l['qty'] as num).toInt();
        lines.add(OrderLine(tid, qty));
        types.add(TicketType(id: tid, name: l['type_name'] as String, price: (l['unit_price'] as num).toDouble(), capacity: qty, maxPerOrder: qty));
      }
      final eventId = ev['id'] as String;
      if (!events.any((e) => e.id == eventId) && !_orderEvents.containsKey(eventId)) {
        _orderEvents[eventId] = EventItem(
          id: eventId,
          name: ev['name'] as String,
          venueId: venue['name'] as String,
          date: _dt(ev['starts_at']),
          place: '${venue['name']}${(venue['zone'] ?? '') == '' ? '' : ' · ${venue['zone']}'}',
          description: '',
          types: types,
          state: EventState.upcoming,
          hue: eventId.hashCode.abs() % 360,
        );
      }
      final o = Order(
        id: j['id'] as String,
        number: j['number'] as String,
        eventId: eventId,
        buyerName: j['buyer_name'] as String,
        ci: '',
        phone: '',
        lines: lines,
        total: (j['total'] as num).toDouble(),
        status: _status(j['status'] as String),
        createdAt: _dt(j['created_at']),
        token: token,
        remote: true,
      );
      _applyOrderJson(o, res);
      orders.add(o);
      notifyListeners();
      return o;
    } catch (_) {
      return null;
    }
  }

  // ---------------- admin / verificador (requiere sesión) ----------------
  bool adminLoading = false;
  String? adminError;

  /// Carga pedidos, eventos, auditoría y verificadores del local del usuario.
  Future<void> loadAdmin() async {
    if (!live) return;
    final me = AppSession.profile.value;
    if (me == null) return;
    adminLoading = true;
    adminError = null;
    notifyListeners();
    try {
      // Eventos y tipos de entrada visibles para este usuario.
      final evRows = await _db.from('events').select('id,name,description,starts_at,status,owner_id');
      final ttRows = await _db.from('ticket_types').select('id,event_id,name,price,capacity,max_per_order,position').order('position').order('price');
      final byEvent = <String, List<TicketType>>{};
      for (final t in (ttRows as List)) {
        final m = Map<String, dynamic>.from(t as Map);
        byEvent.putIfAbsent(m['event_id'] as String, () => []).add(TicketType(
              id: m['id'] as String,
              name: m['name'] as String,
              price: (m['price'] as num).toDouble(),
              capacity: (m['capacity'] as num).toInt(),
              maxPerOrder: (m['max_per_order'] as num?)?.toInt() ?? 6,
            ));
      }
      final now = DateTime.now();
      final evs = <EventItem>[];
      for (final r in (evRows as List)) {
        final m = Map<String, dynamic>.from(r as Map);
        final start = _dt(m['starts_at']);
        final status = m['status'] as String? ?? '';
        final types = byEvent[m['id']] ?? const <TicketType>[];
        evs.add(EventItem(
          id: m['id'] as String,
          name: m['name'] as String,
          venueId: m['owner_id'] as String,
          date: start,
          place: me.venueName,
          description: (m['description'] as String?) ?? '',
          types: types.isEmpty ? [const TicketType(id: '-', name: 'Sin tipos', price: 0, capacity: 0)] : types,
          state: (status == 'finished' || status == 'cancelled')
              ? EventState.finished
              : (status == 'live' || start.difference(now).inDays < 7 ? EventState.active : EventState.upcoming),
          hue: (m['id'] as String).hashCode.abs() % 360,
        ));
      }
      events = evs;

      final rows = await _db.from('orders').select(
          'id,number,event_id,buyer_name,buyer_ci,buyer_phone,buyer_email,total,status,created_at,expires_at,declared_at,decided_at,decided_by,reject_reason,order_lines(ticket_type_id,qty)').order('created_at', ascending: false).limit(300);
      final list = <Order>[];
      for (final r in (rows as List)) {
        final m = Map<String, dynamic>.from(r as Map);
        final created = _dt(m['created_at']);
        final expires = _dt(m['expires_at']);
        list.add(Order(
          id: m['id'] as String,
          number: m['number'] as String,
          eventId: m['event_id'] as String,
          buyerName: m['buyer_name'] as String,
          ci: m['buyer_ci'] as String,
          phone: m['buyer_phone'] as String,
          email: m['buyer_email'] as String?,
          lines: [
            for (final l in ((m['order_lines'] as List?) ?? const []))
              OrderLine((l as Map)['ticket_type_id'] as String, (l['qty'] as num).toInt()),
          ],
          total: (m['total'] as num).toDouble(),
          status: _status(m['status'] as String),
          createdAt: expires.subtract(const Duration(minutes: 15)).isBefore(created) ? created : expires.subtract(const Duration(minutes: 15)),
          token: '',
          declaredAt: _dtn(m['declared_at']),
          decidedAt: _dtn(m['decided_at']),
          decidedBy: m['decided_by'] == null ? null : (m['decided_by'] == me.id ? me.fullName : 'Verificador'),
          rejectReason: m['reject_reason'] as String?,
          remote: true,
        ));
      }
      // Todo pedido debe poder resolver su evento y sus tipos de entrada.
      for (final o in list) {
        final idx = evs.indexWhere((e) => e.id == o.eventId);
        if (idx < 0) {
          evs.add(EventItem(
            id: o.eventId,
            name: 'Evento',
            venueId: me.id,
            date: o.createdAt,
            place: me.venueName,
            description: '',
            types: const [],
            state: EventState.finished,
            hue: 200,
          ));
        }
      }
      for (var i = 0; i < evs.length; i++) {
        final e = evs[i];
        final known = e.types.where((t) => t.id != '-').toList();
        final missing = <String, double>{};
        for (final o in list.where((o) => o.eventId == e.id)) {
          for (final l in o.lines) {
            if (!known.any((t) => t.id == l.typeId)) {
              missing[l.typeId] = o.lines.length == 1 && l.qty > 0 ? o.total / l.qty : 0;
            }
          }
        }
        if (missing.isNotEmpty || known.isEmpty) {
          evs[i] = EventItem(
            id: e.id,
            name: e.name,
            venueId: e.venueId,
            date: e.date,
            place: e.place,
            description: e.description,
            types: [
              ...known,
              for (final m in missing.entries) TicketType(id: m.key, name: 'Entrada', price: m.value, capacity: 0),
              if (known.isEmpty && missing.isEmpty) const TicketType(id: '-', name: 'Sin tipos', price: 0, capacity: 0),
            ],
            state: e.state,
            hue: e.hue,
          );
        }
      }
      events = evs;

      // Conserva los pedidos propios del comprador (con token) si el usuario también compró.
      orders
        ..removeWhere((o) => list.any((x) => x.id == o.id) || o.token.isEmpty)
        ..addAll(list);

      notifications
        ..clear()
        ..addAll([
          for (final o in orders.where((o) => o.status == OrderStatus.verifying && o.declaredAt != null))
            AppNotification(
              at: o.declaredAt!,
              text: 'Un comprador informó un pago de Bs. ${o.total.toStringAsFixed(0)}. Revisa tu cuenta bancaria para confirmar el depósito.',
              orderId: o.id,
            ),
        ])
        ..sort((a, b) => b.at.compareTo(a.at));

      // Auditoría
      final aRows = await _db.from('audit_log').select('created_at,actor_id,actor_permission,action,result,reason,orders(number)').order('created_at', ascending: false).limit(200);
      const labels = {
        'order_approved': 'Aprobó pago',
        'order_rejected': 'Rechazó pago',
        'payment_conflict': 'Intento de decisión bloqueado',
        'verifier_granted': 'Concedió permiso de verificación bancaria',
        'verifier_revoked': 'Revocó permiso de verificación bancaria',
      };
      audit
        ..clear()
        ..addAll([
          for (final r in (aRows as List))
            () {
              final m = Map<String, dynamic>.from(r as Map);
              final isAdminPerm = m['actor_permission'] == 'admin';
              final mine = m['actor_id'] == me.id;
              return AuditEntry(
                at: _dt(m['created_at']),
                actor: mine ? me.fullName : (isAdminPerm ? 'Administrador' : 'Verificador'),
                permission: isAdminPerm ? 'Administrador del local' : 'Verificador delegado de pagos',
                action: labels[m['action']] ?? (m['action'] as String),
                result: switch (m['action']) {
                  'order_approved' => 'Aprobado · QR generados',
                  'order_rejected' => 'Rechazado definitivamente · cupos liberados',
                  'payment_conflict' => 'Conflicto: la orden ya tenía una decisión',
                  'verifier_granted' => 'Permiso activo',
                  'verifier_revoked' => 'Permiso revocado',
                  final x => '$x',
                },
                orderNumber: m['orders'] is Map ? (m['orders'] as Map)['number'] as String? : null,
                reason: m['reason'] as String?,
              );
            }(),
        ]);

      // Verificadores: personal que ya canjeó su código en un evento del local.
      if (me.role == 'admin') {
        final staff = await _db.from('event_staff').select('staff_id,display_name,redeemed_at,revoked_at').not('redeemed_at', 'is', null).filter('revoked_at', 'is', null);
        final pv = await _db.from('payment_verifiers').select('verifier_id,granted_at').filter('revoked_at', 'is', null);
        final granted = {for (final r in (pv as List)) (r as Map)['verifier_id'] as String: _dt(r['granted_at'])};
        final seen = <String>{};
        employees = [
          for (final r in (staff as List))
            if (seen.add((r as Map)['staff_id'] as String))
              Employee(
                id: r['staff_id'] as String,
                name: (r['display_name'] as String?) ?? 'Personal',
                job: 'Staff de puerta',
                verifier: granted.containsKey(r['staff_id']),
                grantedAt: granted[r['staff_id']],
              ),
        ];
        _verifierAllowed = true;
      } else {
        final pv = await _db.from('payment_verifiers').select('verifier_id').eq('verifier_id', me.id).filter('revoked_at', 'is', null);
        _verifierAllowed = (pv as List).isNotEmpty;
      }
    } catch (e) {
      adminError = _msg(e);
    }
    adminLoading = false;
    notifyListeners();
  }

  Future<DecisionResult> _decideRemote(String id, {required bool approve, String? reason}) async {
    try {
      final res = Map<String, dynamic>.from(await _db.rpc('decide_order', params: {
        'p_order_id': id,
        'p_approve': approve,
        'p_reason': reason,
      }) as Map);
      await loadAdmin();
      return res['result'] == 'ok' ? DecisionResult.ok : DecisionResult.conflict;
    } catch (e) {
      await loadAdmin();
      throw StoreException(_msg(e));
    }
  }
}
