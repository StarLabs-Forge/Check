/// Modo demo: toda la app corre con datos simulados, sin Supabase.
///
///   flutter run -d chrome --dart-define=DEMO=true
///
/// Cuentas: `admin@demo.com` (Administrador), `staff@demo.com` (Staff) y
/// `super@demo.com` (Superadministrador), con cualquier contraseña. El rol sale
/// del correo SOLO en la demo (no es seguridad real). Por defecto está apagado.
const bool kDemo = bool.fromEnvironment('DEMO');

/// TEMPORAL: mientras no haya lector de cámara, el escáner ofrece la simulación
/// también con datos reales (marcada como tal y sin registrar ingresos).
/// Se apaga con `--dart-define=SCAN_SIMULATION=false`; quitar al integrar la
/// cámara.
const bool kScanSimulation = bool.fromEnvironment('SCAN_SIMULATION', defaultValue: true);
