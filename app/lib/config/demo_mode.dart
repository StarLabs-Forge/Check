/// Modo demo: toda la app corre con datos simulados, sin Supabase.
///
///   flutter run -d chrome --dart-define=DEMO=true
///
/// Cuentas: `admin@demo.com` (Administrador), `staff@demo.com` (Staff) y
/// `super@demo.com` (Superadministrador), con cualquier contraseña. El rol sale
/// del correo SOLO en la demo (no es seguridad real). Por defecto está apagado.
const bool kDemo = bool.fromEnvironment('DEMO');
