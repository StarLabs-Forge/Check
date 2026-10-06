import '../utils/format.dart';
import '../widgets/admin_scaffold.dart';

num _num(Object? v) {
  if (v is num) return v;
  return num.tryParse('${v ?? 0}') ?? 0;
}

/// Evento + contadores. Se lee de la vista `events_with_stats` (security
/// invoker: respeta RLS) para no hacer N+1 consultas de tickets.
class EventItem {
  const EventItem({
    required this.id,
    required this.name,
    required this.description,
    required this.startsAt,
    required this.endsAt,
    required this.capacity,
    required this.accessType,
    required this.ticketPrice,
    required this.dbStatus,
    required this.ticketsTotal,
    required this.ticketsPaid,
    required this.ticketsPendingPayment,
    required this.checkins,
    required this.ticketsCancelled,
    required this.checkinsLastHour,
  });

  factory EventItem.fromMap(Map<String, dynamic> m) => EventItem(
        id: m['id'] as String,
        name: m['name'] as String,
        description: m['description'] as String?,
        startsAt: DateTime.parse(m['starts_at'] as String).toUtc(),
        endsAt: DateTime.parse(m['ends_at'] as String).toUtc(),
        capacity: _num(m['capacity']).toInt(),
        accessType: m['access_type'] as String,
        ticketPrice: _num(m['ticket_price']).toDouble(),
        dbStatus: m['status'] as String,
        ticketsTotal: _num(m['tickets_total']).toInt(),
        ticketsPaid: _num(m['tickets_paid']).toInt(),
        ticketsPendingPayment: _num(m['tickets_pending_payment']).toInt(),
        checkins: _num(m['checkins']).toInt(),
        ticketsCancelled: _num(m['tickets_cancelled']).toInt(),
        checkinsLastHour: _num(m['checkins_last_hour']).toInt(),
      );

  final String id;
  final String name;
  final String? description;
  final DateTime startsAt;
  final DateTime endsAt;
  final int capacity;

  /// `free` | `paid`
  final String accessType;
  final double ticketPrice;

  /// `draft` | `active` | `live` | `finished` | `suspended`
  final String dbStatus;

  final int ticketsTotal;
  final int ticketsPaid;
  final int ticketsPendingPayment;
  final int checkins;
  final int ticketsCancelled;
  final int checkinsLastHour;

  String get date => Fmt.date(startsAt);
  String get time => Fmt.time(startsAt);

  double get occupancy => capacity == 0 ? 0 : checkins / capacity;
  int get pending => (capacity - checkins).clamp(0, capacity);

  bool get isPaid => accessType == 'paid';
  bool get isDraft => dbStatus == 'draft';
  bool get isActive => dbStatus == 'active';
  bool get isLive => dbStatus == 'live';
  bool get isOpen => isActive || isLive;

  // Transiciones permitidas por el trigger `guard_event`:
  // draft->active, active->draft, active->live, live->finished, active->finished.
  bool get canActivate => isDraft;
  bool get canGoLive => isActive;
  bool get canClose => isActive || isLive;
  bool get canIssueTickets => !(dbStatus == 'finished' || dbStatus == 'suspended');

  BadgeStatus get status => switch (dbStatus) {
        'draft' => BadgeStatus.borrador,
        'active' || 'live' => BadgeStatus.activo,
        _ => BadgeStatus.cerrado, // finished | suspended
      };
}

/// Ticket / invitado.
class GuestItem {
  const GuestItem({
    required this.id,
    required this.eventId,
    required this.name,
    required this.phone,
    required this.paymentStatus,
    required this.ticketStatus,
    required this.checkedInAt,
    required this.eventName,
  });

  factory GuestItem.fromMap(Map<String, dynamic> m) {
    final event = m['events'];
    final checkedIn = m['checked_in_at'] as String?;
    return GuestItem(
      id: m['id'] as String,
      eventId: m['event_id'] as String,
      name: m['guest_name'] as String,
      phone: m['guest_phone'] as String?,
      paymentStatus: m['payment_status'] as String,
      ticketStatus: m['status'] as String,
      checkedInAt: checkedIn == null ? null : DateTime.parse(checkedIn).toUtc(),
      eventName: event is Map ? (event['name'] as String? ?? '') : '',
    );
  }

  final String id;
  final String eventId;
  final String name;
  final String? phone;

  /// `pending` | `paid`
  final String paymentStatus;

  /// `issued` | `used` | `cancelled`
  final String ticketStatus;
  final DateTime? checkedInAt;
  final String eventName;

  BadgeStatus get status {
    if (ticketStatus == 'used') return BadgeStatus.ingreso;
    if (ticketStatus == 'cancelled') return BadgeStatus.cancelado;
    // issued
    return paymentStatus == 'pending' ? BadgeStatus.porCobrar : BadgeStatus.pendiente;
  }

  /// Hora de ingreso, o "—" si todavía no ingresó.
  String get time => checkedInAt == null ? '—' : Fmt.time(checkedInAt!);
}

/// Resultado de `create_ticket`. El token del QR **solo** se devuelve en este
/// momento (en la base solo queda su hash SHA-256), por eso hay que mostrarlo
/// de inmediato.
class CreatedTicket {
  const CreatedTicket({required this.ticketId, required this.qrToken, required this.paymentStatus});

  factory CreatedTicket.fromMap(Map<String, dynamic> m) => CreatedTicket(
        ticketId: m['ticket_id'] as String,
        qrToken: m['qr_token'] as String,
        paymentStatus: m['payment_status'] as String,
      );

  final String ticketId;
  final String qrToken;
  final String paymentStatus;
}
