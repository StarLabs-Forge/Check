import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/demo_mode.dart';
import 'app_session.dart';

/// Wrapper fino de Supabase Auth. La navegación posterior al login/logout la
/// decide el listener de `main.dart` (una sola fuente de verdad), no estas
/// funciones.
class AuthService {
  const AuthService._();

  static GoTrueClient get _auth => Supabase.instance.client.auth;

  /// Modo demo: avisa a `main.dart` cuando se "inicia" o "cierra" sesión.
  static final StreamController<bool> demoSession = StreamController<bool>.broadcast();

  static const _demoOnly = 'Modo demo: entra con admin@demo.com o super@demo.com (cualquier contraseña).';

  static Future<void> signIn({required String email, required String password}) async {
    if (kDemo) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      AppSession.signInDemo(email);
      demoSession.add(true);
      return;
    }
    await _auth.signInWithPassword(email: email.trim(), password: password);
  }

  /// Registra un Admin/Organizador. `full_name` lo lee el trigger
  /// `handle_new_user` para crear el perfil; `venue_name` queda en metadata.
  ///
  /// Devuelve `true` si ya hay sesión (confirmación de correo desactivada) o
  /// `false` si falta confirmar el correo con el código.
  /// Lanza [AuthException] si el correo ya existe.
  static Future<bool> signUp({
    required String fullName,
    required String venueName,
    required String email,
    required String password,
  }) async {
    if (kDemo) throw AuthException(_demoOnly);
    final res = await _auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': fullName.trim(), 'venue_name': venueName.trim()},
    );

    // Con confirmación activa, Supabase NO devuelve error si el correo ya
    // existe (anti-enumeración): devuelve un usuario sin identidades.
    final identities = res.user?.identities;
    if (res.session == null && identities != null && identities.isEmpty) {
      throw AuthException('User already registered', code: 'user_already_exists');
    }
    return res.session != null;
  }

  static Future<void> verifySignupCode({required String email, required String code}) async {
    await _auth.verifyOTP(email: email.trim(), token: code.trim(), type: OtpType.signup);
  }

  static Future<void> resendSignupCode(String email) async {
    await _auth.resend(type: OtpType.signup, email: email.trim());
  }

  /// OAuth con Google. Requiere habilitar el proveedor en Supabase
  /// (Authentication → Providers → Google) y registrar la URL de redirección.
  static Future<void> signInWithGoogle() async {
    if (kDemo) throw AuthException(_demoOnly);
    await _auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : 'io.supabase.check://login-callback/',
    );
  }

  /// Completa los datos que el registro con correo ya pide y Google no entrega:
  /// el local queda en `user_metadata.venue_name` y el nombre en `profiles`.
  static Future<void> completeProfile({required String fullName, required String venueName}) async {
    final res = await _auth.updateUser(
      UserAttributes(data: {'full_name': fullName.trim(), 'venue_name': venueName.trim()}),
    );
    final id = res.user?.id ?? _auth.currentUser!.id;
    await Supabase.instance.client
        .from('profiles')
        .update({'full_name': fullName.trim()})
        .eq('id', id);
  }

  static Future<void> signOut() {
    if (kDemo) {
      AppSession.clear();
      demoSession.add(false);
      return Future<void>.value();
    }
    return _auth.signOut();
  }
}
