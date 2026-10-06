// Modelos de la app móvil Staff. Independientes de `lib/data/models.dart`
// (que es del panel Admin y depende de widgets web) para que el móvil pueda
// compilarse y probarse solo.

class StaffEvent {
  const StaffEvent({
    required this.id,
    required this.name,
    required this.startsAt,
    required this.capacity,
    required this.checkins,
  });

  final String id;
  final String name;
  final DateTime startsAt;
  final int capacity;
  final int checkins;

  /// 0–100, como espera `StaffProgressBar`.
  double get progress => capacity == 0 ? 0 : (checkins / capacity * 100).clamp(0, 100).toDouble();

  StaffEvent copyWith({int? checkins}) => StaffEvent(
        id: id,
        name: name,
        startsAt: startsAt,
        capacity: capacity,
        checkins: checkins ?? this.checkins,
      );
}

class StaffGuest {
  const StaffGuest({
    required this.id,
    required this.eventId,
    required this.name,
    this.phone,
    this.checkedInAt,
  });

  final String id;
  final String eventId;
  final String name;
  final String? phone;
  final DateTime? checkedInAt;

  bool get hasEntered => checkedInAt != null;

  StaffGuest copyWith({DateTime? checkedInAt}) => StaffGuest(
        id: id,
        eventId: eventId,
        name: name,
        phone: phone,
        checkedInAt: checkedInAt ?? this.checkedInAt,
      );
}

/// Los tres resultados a pantalla completa del Figma (Scanner Result Screen).
enum ScanResultKind {
  /// Verde · "ACCESO PERMITIDO"
  success,

  /// Amarillo · "YA REGISTRADO"
  alreadyRegistered,

  /// Rojo · "ACCESO DENEGADO"
  denied,
}

class ScanOutcome {
  const ScanOutcome._({
    required this.kind,
    this.guestName,
    this.checkedInAt,
    this.checkins,
    this.capacity,
  });

  const ScanOutcome.success({
    required String guestName,
    required DateTime checkedInAt,
    required int checkins,
    required int capacity,
  }) : this._(
          kind: ScanResultKind.success,
          guestName: guestName,
          checkedInAt: checkedInAt,
          checkins: checkins,
          capacity: capacity,
        );

  const ScanOutcome.alreadyRegistered({required String guestName, required DateTime checkedInAt})
      : this._(kind: ScanResultKind.alreadyRegistered, guestName: guestName, checkedInAt: checkedInAt);

  const ScanOutcome.denied() : this._(kind: ScanResultKind.denied);

  final ScanResultKind kind;
  final String? guestName;
  final DateTime? checkedInAt;
  final int? checkins;
  final int? capacity;
}
