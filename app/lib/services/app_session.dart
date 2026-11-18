import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/demo_mode.dart';
import '../utils/format.dart';

/// Perfil del usuario logueado (tabla `profiles` + metadata de Auth).
class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    required this.role,
    required this.plan,
    required this.status,
    required this.venueName,
  });

  final String id;
  final String fullName;

  /// `super_admin` | `admin` | `staff`
  final String role;

  /// `starter` | `pro` | `premium`
  final String plan;

  /// `active` | `suspended`
  final String status;

  /// Nombre del local/organización. Se guarda en `user_metadata.venue_name`
  /// al registrarse (la tabla `profiles` todavía no tiene columna para eso).
  final String venueName;

  String get initials => Fmt.initials(fullName);

  String get roleLabel => switch (role) {
        'super_admin' => 'Super admin',
        'staff' => 'Staff',
        _ => 'Administrador',
      };
}

/// Estado de sesión global de la app. El panel Admin lee de acá el nombre,
/// el local y el plan; se llena después de autenticarse.
class AppSession {
  const AppSession._();

  static final ValueNotifier<Profile?> profile = ValueNotifier<Profile?>(null);

  static SupabaseClient get _db => Supabase.instance.client;

  /// Carga el perfil del usuario actual. Devuelve `null` si todo bien, o un
  /// mensaje de error (cuenta de staff, suspendida, sin perfil...). En caso de
  /// error la sesión se cierra para no dejar al usuario "a medias".
  static Future<String?> load() async {
    final user = _db.auth.currentUser;
    if (user == null) return 'No hay una sesión activa.';

    try {
      final row = await _db.from('profiles').select().eq('id', user.id).maybeSingle();
      if (row == null) {
        await _db.auth.signOut();
        return 'No encontramos tu perfil. Contacta a soporte.';
      }

      final role = row['role'] as String;
      final status = row['status'] as String;

      if (status == 'suspended') {
        await _db.auth.signOut();
        return 'Tu cuenta está suspendida.';
      }

      final meta = user.userMetadata ?? const <String, dynamic>{};
      final venue = (meta['venue_name'] as String?)?.trim();
      final fullName = (row['full_name'] as String?)?.trim() ?? '';

      profile.value = Profile(
        id: user.id,
        fullName: fullName.isNotEmpty ? fullName : (user.email ?? 'Administrador'),
        role: role,
        plan: row['plan'] as String,
        status: status,
        venueName: (venue == null || venue.isEmpty) ? 'Mi local' : venue,
      );
      return null;
    } catch (_) {
      return 'No pudimos cargar tu perfil. Revisa tu conexión e intenta de nuevo.';
    }
  }

  /// `true` si falta el nombre del local, que el registro con correo siempre
  /// guarda y el de Google no (ver `CompleteProfileScreen`).
  static bool get needsProfileCompletion {
    if (kDemo) return false;
    final meta = _db.auth.currentUser?.userMetadata ?? const <String, dynamic>{};
    final venue = (meta['venue_name'] as String?)?.trim();
    return venue == null || venue.isEmpty;
  }

  /// Ruta de entrada tras autenticarse.
  /// Panel de destino según el rol autenticado (el rol sale de `profiles`).
  static String get entryRoute {
    switch (profile.value?.role) {
      case 'super_admin':
        return '/superadmin';
      case 'staff':
        return '/staff';
      default:
        return needsProfileCompletion ? '/completar-perfil' : '/home';
    }
  }

  /// Modo demo: perfil simulado según el correo (`super…` = superadmin).
  static void signInDemo(String email) {
    final e = email.trim().toLowerCase();
    final isSuper = e.startsWith('super');
    final isStaff = e.startsWith('staff');
    profile.value = Profile(
      id: isSuper ? 'demo-super' : (isStaff ? 'demo-staff' : 'demo-admin'),
      fullName: isSuper ? 'Equipo CHECK' : (isStaff ? 'Marco Limachi' : 'Carla Mendoza'),
      role: isSuper ? 'super_admin' : (isStaff ? 'staff' : 'admin'),
      plan: 'pro',
      status: 'active',
      venueName: isSuper ? 'Plataforma CHECK' : 'Dharma Club',
    );
  }

  static void clear() => profile.value = null;
}
