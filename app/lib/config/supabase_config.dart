/// Configuración de Supabase por entorno.
///
/// La URL y la *publishable key* (`sb_publishable_...`) son públicas por diseño:
/// viajan en cualquier app cliente y la seguridad la imponen las políticas RLS.
/// NUNCA pongas acá la `service_role` / secret key.
///
///   Producción:  flutter build web                                     (por defecto)
///   Desarrollo:  flutter run -d chrome --dart-define-from-file=env/dev.json
///   Demo:        flutter run -d chrome --dart-define=DEMO=true          (sin Supabase)
class SupabaseConfig {
  const SupabaseConfig._();

  /// Referencia del proyecto de producción: un build de desarrollo nunca puede usarla.
  static const String productionRef = 'lvejfwatzdqpzftjraut';

  /// `prod` (por defecto) o `dev`.
  static const String env = String.fromEnvironment('APP_ENV', defaultValue: 'prod');

  static bool get isDev => env == 'dev';

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://$productionRef.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_45XCo6MIZ4Z1ERCD45Vk1Q_D4qIS4RW',
  );

  /// Motivo por el que la configuración es inválida, o `null` si es coherente.
  static String? problem({String env = env, String url = url}) {
    if (env != 'prod' && env != 'dev') return 'APP_ENV debe ser "prod" o "dev" (llegó "$env").';
    if (env == 'dev' && url.contains(productionRef)) {
      return 'APP_ENV=dev apunta al proyecto de producción. Usa --dart-define-from-file=env/dev.json.';
    }
    if (env == 'prod' && !url.contains(productionRef)) {
      return 'APP_ENV=prod apunta a un proyecto distinto del de producción.';
    }
    return null;
  }
}
