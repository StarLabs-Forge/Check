import '../widgets/admin_scaffold.dart';

/// Datos de ejemplo del panel Admin — SIN Supabase todavía. Mismos valores
/// que trae el archivo de Figma (frames "Lista de Eventos", "Detalle de
/// Evento — Eclipse Party" y "Admin · Tickets") para que la demo de las
/// pantallas se vea idéntica a la referencia de diseño.
class EventItem {
  const EventItem({
    required this.id,
    required this.name,
    required this.date,
    required this.time,
    required this.capacity,
    required this.checkins,
    required this.status,
  });

  final String id;
  final String name;
  final String date;
  final String time;
  final int capacity;
  final int checkins;
  final BadgeStatus status;

  double get occupancy => capacity == 0 ? 0 : checkins / capacity;
}

class GuestItem {
  const GuestItem({
    required this.name,
    required this.status,
    required this.time,
    required this.eventName,
  });

  final String name;
  final BadgeStatus status;

  /// Hora de ingreso, o "—" si todavía no ingresa.
  final String time;
  final String eventName;
}

const mockEvents = <EventItem>[
  EventItem(
    id: 'eclipse-party',
    name: 'Eclipse Party',
    date: '12 Sep 2025',
    time: '22:00',
    capacity: 200,
    checkins: 143,
    status: BadgeStatus.activo,
  ),
  EventItem(
    id: 'noche-de-jazz',
    name: 'Noche de Jazz',
    date: '19 Sep 2025',
    time: '21:00',
    capacity: 150,
    checkins: 0,
    status: BadgeStatus.borrador,
  ),
  EventItem(
    id: 'closing-party',
    name: 'Closing Party',
    date: '26 Sep 2025',
    time: '23:00',
    capacity: 300,
    checkins: 300,
    status: BadgeStatus.cerrado,
  ),
];

/// Invitados del detalle de "Eclipse Party".
const mockEclipseGuests = <GuestItem>[
  GuestItem(name: 'Valentina Quispe', status: BadgeStatus.ingreso, time: '21:34', eventName: 'Eclipse Party'),
  GuestItem(name: 'Rodrigo Mamani', status: BadgeStatus.ingreso, time: '21:41', eventName: 'Eclipse Party'),
  GuestItem(name: 'Camila Torrez', status: BadgeStatus.pendiente, time: '—', eventName: 'Eclipse Party'),
  GuestItem(name: 'Diego Alvarado', status: BadgeStatus.ingreso, time: '22:05', eventName: 'Eclipse Party'),
  GuestItem(name: 'Sofía Mendez', status: BadgeStatus.pendiente, time: '—', eventName: 'Eclipse Party'),
  GuestItem(name: 'Andrés Condori', status: BadgeStatus.ingreso, time: '22:18', eventName: 'Eclipse Party'),
  GuestItem(name: 'Lucía Vargas', status: BadgeStatus.cancelado, time: '—', eventName: 'Eclipse Party'),
];

/// Todos los tickets emitidos en el local, de cualquier evento (frame
/// "Admin · Tickets").
const mockAllTickets = <GuestItem>[
  GuestItem(name: 'Valentina Quispe', status: BadgeStatus.ingreso, time: '21:34', eventName: 'Eclipse Party'),
  GuestItem(name: 'Rodrigo Mamani', status: BadgeStatus.ingreso, time: '21:41', eventName: 'Noche de Jazz'),
  GuestItem(name: 'Camila Torrez', status: BadgeStatus.pendiente, time: '—', eventName: 'Closing Party'),
  GuestItem(name: 'Diego Alvarado', status: BadgeStatus.ingreso, time: '22:05', eventName: 'Eclipse Party'),
  GuestItem(name: 'Sofía Mendez', status: BadgeStatus.pendiente, time: '—', eventName: 'Noche de Jazz'),
  GuestItem(name: 'Andrés Condori', status: BadgeStatus.ingreso, time: '22:18', eventName: 'Closing Party'),
  GuestItem(name: 'Lucía Vargas', status: BadgeStatus.cancelado, time: '—', eventName: 'Eclipse Party'),
];
