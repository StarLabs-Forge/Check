/// Modo demo: toda la app corre con datos simulados, sin Supabase.
///
///   flutter run -d chrome --dart-define=DEMO=true
///
/// Cuentas: `admin@demo.com` (Administrador) y `super@demo.com`
/// (Superadministrador), con cualquier contraseña. Por defecto está apagado.
const bool kDemo = bool.fromEnvironment('DEMO');
