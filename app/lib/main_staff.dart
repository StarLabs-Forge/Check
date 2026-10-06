import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'staff/staff_app.dart';

/// Punto de entrada de la app móvil Staff (rama móvil).
///
///   flutter run -t lib/main_staff.dart
///
/// Usa `MockStaffRepository` (sin Supabase): código `123456`, PIN `1234`.
/// El panel Admin sigue arrancando con `lib/main.dart`, sin cambios.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Puerta de evento: siempre vertical.
  await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
  runApp(StaffApp());
}
