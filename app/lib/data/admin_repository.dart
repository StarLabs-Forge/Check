import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/demo_mode.dart';
import 'demo_admin_data.dart';
import 'models.dart';

/// Acceso a datos del panel Admin. Todo pasa por PostgREST/RPC con la sesión
/// del usuario, así que la seguridad real la imponen las políticas RLS y las
/// funciones SECURITY DEFINER de la base (el cliente NO decide permisos).
class AdminRepository {
  AdminRepository._();
  static final AdminRepository instance = AdminRepository._();

  SupabaseClient get _db => Supabase.instance.client;

  static const _ticketColumns =
      'id, event_id, guest_name, guest_phone, payment_status, status, checked_in_at, created_at, events(name)';

  // ───────────────────────── Eventos ─────────────────────────

  /// Todos los eventos del admin (más recientes primero) con sus contadores.
  Future<List<EventItem>> listEvents() async {
    if (kDemo) return DemoAdminData.instance.listEvents();
    final rows = await _db.from('events_with_stats').select().order('starts_at', ascending: false);
    return rows.map<EventItem>((r) => EventItem.fromMap(r)).toList();
  }

  Future<EventItem?> getEvent(String id) async {
    if (kDemo) return DemoAdminData.instance.getEvent(id);
    final row = await _db.from('events_with_stats').select().eq('id', id).maybeSingle();
    return row == null ? null : EventItem.fromMap(row);
  }

  /// Crea un evento. El trigger `guard_event` lo fuerza a `draft` y valida el
  /// límite mensual del plan (error `plan_limit_events`).
  Future<void> createEvent({
    required String name,
    String? description,
    required DateTime startsAt,
    required DateTime endsAt,
    required int capacity,
    required bool paid,
    double price = 0,
  }) async {
    if (kDemo) {
      return DemoAdminData.instance.createEvent(
        name: name,
        description: description,
        startsAt: startsAt,
        endsAt: endsAt,
        capacity: capacity,
        paid: paid,
        price: price,
      );
    }
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw AuthException('No hay sesión activa');
    await _db.from('events').insert({
      'owner_id': uid,
      'name': name.trim(),
      'description': (description == null || description.trim().isEmpty) ? null : description.trim(),
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'capacity': capacity,
      'access_type': paid ? 'paid' : 'free',
      'ticket_price': paid ? price : 0,
    });
  }

  /// Edita un evento. RLS limita la fila al dueño y `guard_event` rechaza
  /// capacidad por debajo de lo vendido, cambio de precio con ventas y
  /// eventos cerrados (`capacity_below_sold`, `price_locked_with_sales`, `event_locked`).
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
    if (kDemo) {
      return DemoAdminData.instance.updateEvent(
        id: id,
        name: name,
        description: description,
        startsAt: startsAt,
        endsAt: endsAt,
        capacity: capacity,
        paid: paid,
        price: price,
      );
    }
    final updated = await _db.from('events').update({
      'name': name.trim(),
      'description': (description == null || description.trim().isEmpty) ? null : description.trim(),
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'capacity': capacity,
      'access_type': paid ? 'paid' : 'free',
      'ticket_price': paid ? price : 0,
    }).eq('id', id).select('id');
    if (updated.isEmpty) throw const PostgrestException(message: 'forbidden', code: '42501');
  }

  /// Cambia el estado (`active`, `live`, `finished`...) SOLO mediante la RPC
  /// `set_event_status`, que valida y audita. No hay vía alternativa: si el
  /// esquema no la tiene, se informa la incompatibilidad en vez de escribir sin
  /// auditoría.
  Future<void> setEventStatus(String eventId, String status, {String? reason}) async {
    if (kDemo) return DemoAdminData.instance.setEventStatus(eventId, status);
    try {
      await _db.rpc('set_event_status', params: {
        'p_event_id': eventId,
        'p_status': status,
        'p_reason': (reason == null || reason.trim().isEmpty) ? null : reason.trim(),
      });
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST202') {
        throw const PostgrestException(message: 'schema_outdated', code: 'PGRST202');
      }
      rethrow;
    }
  }

  // ───────────────────────── Categorías de entrada ─────────────────────────

  /// Categorías del evento con vendidas/reservadas/disponibles (`ticket_type_stats`).
  /// Sin demo: la demo no tiene categorías persistidas.
  Future<List<TicketCategory>> listCategories(String eventId) async {
    if (kDemo) return const [];
    final rows = await _db
        .from('ticket_types')
        .select('id, name, description, price, capacity, max_per_order, position, active')
        .eq('event_id', eventId)
        .order('position')
        .order('price');
    // Sin datos de relleno: si las cifras fallan, el error se muestra.
    final res = await _db.rpc('ticket_type_stats', params: {'p_event_id': eventId});
    final stats = {for (final m in (res as List)) (m as Map)['id'] as String: Map<String, dynamic>.from(m)};
    return rows.map<TicketCategory>((r) {
      final st = stats[r['id']];
      return TicketCategory(
        id: r['id'] as String,
        name: r['name'] as String,
        description: (r['description'] as String?) ?? '',
        price: (r['price'] as num).toDouble(),
        capacity: (r['capacity'] as num).toInt(),
        maxPerOrder: (r['max_per_order'] as num).toInt(),
        active: (r['active'] as bool?) ?? true,
        sold: (st?['sold'] as num?)?.toInt(),
        reserved: (st?['reserved'] as num?)?.toInt(),
        available: (st?['available'] as num?)?.toInt(),
      );
    }).toList();
  }

  /// Crea (`id == null`) o edita una categoría. Los pedidos existentes conservan su
  /// precio (`order_lines.unit_price`); el cupo no puede bajar de lo vendido/reservado
  /// (trigger `guard_ticket_type_capacity`).
  Future<void> saveCategory({
    String? id,
    required String eventId,
    required String name,
    String? description,
    required double price,
    required int capacity,
    required int maxPerOrder,
    required bool active,
  }) async {
    final desc = (description == null || description.trim().isEmpty) ? null : description.trim();
    final data = {
      'name': name.trim(),
      'description': desc,
      'price': price,
      'capacity': capacity,
      'max_per_order': maxPerOrder,
      'active': active,
    };
    if (id == null) {
      await _db.from('ticket_types').insert({...data, 'event_id': eventId});
    } else {
      final rows = await _db.from('ticket_types').update(data).eq('id', id).select('id');
      if (rows.isEmpty) throw const PostgrestException(message: 'forbidden', code: '42501');
    }
  }

  /// Elimina una categoría sin operaciones asociadas; si tiene pedidos o entradas la
  /// base lo rechaza (FK, código 23503) y hay que desactivarla en su lugar.
  Future<void> deleteCategory(String id) async {
    final rows = await _db.from('ticket_types').delete().eq('id', id).select('id');
    if (rows.isEmpty) throw const PostgrestException(message: 'forbidden', code: '42501');
  }

  /// Pagos informados sin revisar de eventos cuyo corte (10:00 del día del evento,
  /// hora de Bolivia) ya pasó. Solo informa. Vacío en demo o sin la migración 23.
  Future<List<CutoffAlert>> paymentCutoffAlerts() async {
    if (kDemo) return const [];
    try {
      final res = await _db.rpc('payment_cutoff_alerts');
      return [
        for (final m in (res as List).cast<Map>())
          CutoffAlert(eventName: m['event_name'] as String, pending: (m['pending'] as num).toInt()),
      ];
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST202') return const [];
      rethrow;
    }
  }

  // ───────────────────────── Prueba gratuita ─────────────────────────

  /// Estado de la prueba de 14 días, calculado en el servidor (`trial_status`).
  /// `null` si no se activó o si la migración 14 aún no existe.
  Future<TrialStatus?> trialStatus() async {
    if (kDemo) throw StateError('demo');
    try {
      final res = await _db.rpc('trial_status');
      return res == null ? null : TrialStatus.fromMap(Map<String, dynamic>.from(res as Map));
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST202') throw StateError('migration_14_missing');
      rethrow;
    }
  }

  /// Activa la prueba (una sola vez; repetirla no reinicia el periodo).
  Future<TrialStatus?> startTrial() async {
    final res = await _db.rpc('start_trial');
    return res == null ? null : TrialStatus.fromMap(Map<String, dynamic>.from(res as Map));
  }

  // ───────────────────────── Tickets ─────────────────────────

  /// Tickets (opcionalmente de un evento, opcionalmente filtrados por nombre).
  Future<List<GuestItem>> listTickets({String? eventId, String query = '', int limit = 500}) async {
    if (kDemo) return DemoAdminData.instance.listTickets(eventId: eventId, query: query, limit: limit);
    var filter = _db.from('tickets').select(_ticketColumns);
    if (eventId != null) filter = filter.eq('event_id', eventId);
    final q = query.trim();
    if (q.isNotEmpty) {
      // Escapa comodines de LIKE para que el texto se busque literal.
      final safe = q.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
      filter = filter.ilike('guest_name', '%$safe%');
    }
    final rows = await filter.order('created_at', ascending: false).limit(limit);
    return rows.map<GuestItem>((r) => GuestItem.fromMap(r)).toList();
  }

  /// Últimos ingresos de un evento (feed del dashboard).
  Future<List<GuestItem>> recentCheckins(String eventId, {int limit = 4}) async {
    if (kDemo) return DemoAdminData.instance.recentCheckins(eventId, limit: limit);
    final rows = await _db
        .from('tickets')
        .select(_ticketColumns)
        .eq('event_id', eventId)
        .eq('status', 'used')
        .order('checked_in_at', ascending: false)
        .limit(limit);
    return rows.map<GuestItem>((r) => GuestItem.fromMap(r)).toList();
  }

  /// Emite un ticket vía RPC `create_ticket` (valida dueño, cuota del plan y
  /// estado del evento). Devuelve el token del QR, que no se puede recuperar
  /// después.
  Future<CreatedTicket> createTicket({
    required String eventId,
    required String guestName,
    String? guestPhone,
    bool paid = false,
    String? ticketTypeId,
  }) async {
    if (kDemo) {
      return DemoAdminData.instance.createTicket(eventId: eventId, guestName: guestName, guestPhone: guestPhone, paid: paid);
    }
    final res = await _db.rpc('create_ticket', params: {
      'p_event_id': eventId,
      'p_guest_name': guestName.trim(),
      'p_guest_phone': (guestPhone == null || guestPhone.trim().isEmpty) ? null : guestPhone.trim(),
      'p_payment_status': paid ? 'paid' : 'pending',
      // Obligatoria desde la migración 18; antes de ella no se envía.
      'p_ticket_type_id': ?ticketTypeId,
    });
    return CreatedTicket.fromMap(Map<String, dynamic>.from(res as Map));
  }
}

/// Estado comercial del local. `state`: `active` | `expiring` | `expired`
/// (prueba), `subscribed` (plan contratado) o `plan_ended`.
class TrialStatus {
  const TrialStatus({required this.state, required this.daysLeft, this.endsAt, this.plan});
  final String state;
  final int daysLeft;
  final DateTime? endsAt;
  final String? plan;

  bool get expired => state == 'expired';

  factory TrialStatus.fromMap(Map<String, dynamic> m) => TrialStatus(
        state: m['state'] as String,
        daysLeft: (m['days_left'] as num).toInt(),
        endsAt: m['ends_at'] == null ? null : DateTime.parse(m['ends_at'] as String).toLocal(),
        plan: m['plan'] as String?,
      );
}

/// Categoría de entrada de un evento. `sold/reserved/available` son null si la
/// migración 14 (ticket_type_stats) aún no está aplicada.
class TicketCategory {
  const TicketCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.capacity,
    required this.maxPerOrder,
    required this.active,
    this.sold,
    this.reserved,
    this.available,
  });
  final String id;
  final String name;
  final String description;
  final double price;
  final int capacity;
  final int maxPerOrder;
  final bool active;
  final int? sold;
  final int? reserved;
  final int? available;

  bool get hasOperations => (sold ?? 0) + (reserved ?? 0) > 0;
}

/// Aviso de pagos sin revisar pasado el corte de un evento.
class CutoffAlert {
  const CutoffAlert({required this.eventName, required this.pending});
  final String eventName;
  final int pending;
}
