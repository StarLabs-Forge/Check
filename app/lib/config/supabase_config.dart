/// Configuración de Supabase.
///
/// La URL y la *publishable key* (`sb_publishable_...`) son públicas por
/// diseño: viajan en cualquier app cliente y la seguridad real la imponen las
/// políticas RLS de la base. Aun así se pueden sobreescribir por entorno:
///
///   flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=sb_publishable_xxx
///
/// NUNCA pongas acá la `service_role` / secret key.
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://lvejfwatzdqpzftjraut.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_45XCo6MIZ4Z1ERCD45Vk1Q_D4qIS4RW',
  );
}
