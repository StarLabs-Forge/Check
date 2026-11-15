import 'package:supabase_flutter/supabase_flutter.dart';

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
    final rows = await _db.from('events_with_stats').select().order('starts_at', ascending: false);
    return rows.map<EventItem>((r) => EventItem.fromMap(r)).toList();
  }

  Future<EventItem?> getEvent(String id) async {
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

  /// Cambia el estado (`active`, `live`, `finished`...). Las transiciones
  /// inválidas las rechaza el trigger `guard_event`.
  Future<void> setEventStatus(String eventId, String status) async {
    await _db.from('events').update({'status': status}).eq('id', eventId);
  }

  // ───────────────────────── Tickets ─────────────────────────

  /// Tickets (opcionalmente de un evento, opcionalmente filtrados por nombre).
  Future<List<GuestItem>> listTickets({String? eventId, String query = '', int limit = 500}) async {
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
  }) async {
    final res = await _db.rpc('create_ticket', params: {
      'p_event_id': eventId,
      'p_guest_name': guestName.trim(),
      'p_guest_phone': (guestPhone == null || guestPhone.trim().isEmpty) ? null : guestPhone.trim(),
      'p_payment_status': paid ? 'paid' : 'pending',
    });
    return CreatedTicket.fromMap(Map<String, dynamic>.from(res as Map));
  }
}
