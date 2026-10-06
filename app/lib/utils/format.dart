/// Formateo de fechas/horas en hora de La Paz (UTC-4 fijo, Bolivia no usa
/// horario de verano) sin depender de `intl`.
///
/// La base guarda `timestamptz` en UTC. Para mostrar, se resta el offset y se
/// leen los campos del DateTime resultante (que queda "en UTC" pero con la
/// hora de pared de La Paz). Para guardar, se hace el camino inverso.
class Fmt {
  const Fmt._();

  static const Duration _offset = Duration(hours: 4);

  static const _monthsShort = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
  static const _monthsLong = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];
  static const _weekdays = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

  /// UTC -> hora de pared de La Paz.
  static DateTime toLaPaz(DateTime d) => d.toUtc().subtract(_offset);

  /// Hora de pared de La Paz -> instante UTC (lo que se guarda en la DB).
  static DateTime fromLaPaz(int y, int m, int d, int h, int min) =>
      DateTime.utc(y, m, d, h, min).add(_offset);

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// "12 Sep 2025"
  static String date(DateTime utc) {
    final l = toLaPaz(utc);
    return '${l.day} ${_monthsShort[l.month - 1]} ${l.year}';
  }

  /// "22:00"
  static String time(DateTime utc) {
    final l = toLaPaz(utc);
    return '${_two(l.hour)}:${_two(l.minute)}';
  }

  /// "Viernes, 12 de septiembre de 2025"
  static String longToday([DateTime? now]) {
    final l = toLaPaz(now ?? DateTime.now());
    return '${_weekdays[l.weekday - 1]}, ${l.day} de ${_monthsLong[l.month - 1]} de ${l.year}';
  }

  /// "dd/mm/aaaa" a partir de una fecha local (sin hora).
  static String dmy(DateTime local) => '${_two(local.day)}/${_two(local.month)}/${local.year}';

  static String hm(int hour, int minute) => '${_two(hour)}:${_two(minute)}';

  /// Iniciales para el avatar: "Napoleón Flores" -> "NF".
  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  static String money(double v) {
    final isInt = v == v.roundToDouble();
    return 'Bs. ${isInt ? v.toStringAsFixed(0) : v.toStringAsFixed(2)}';
  }
}
