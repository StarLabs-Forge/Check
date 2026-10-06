import 'package:flutter/widgets.dart';

import 'data/staff_repository.dart';

/// Expone el [StaffRepository] a todo el árbol de la app Staff.
class StaffScope extends InheritedWidget {
  const StaffScope({super.key, required this.repository, required super.child});

  final StaffRepository repository;

  static StaffRepository of(BuildContext context) {
    // getInherited…: el repositorio no cambia en caliente y así se puede leer
    // también desde initState sin romper la regla de dependencias.
    final scope = context.getInheritedWidgetOfExactType<StaffScope>();
    assert(scope != null, 'StaffScope no encontrado en el árbol de widgets');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(StaffScope old) => repository != old.repository;
}

/// "HH:mm" en hora local del dispositivo (La Paz = UTC-4 fijo).
String hhmm(DateTime t) {
  final l = t.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}
