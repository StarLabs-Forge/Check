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

  static const _demoOnly = 'Modo demo: entra con admin@demo.com, staff@demo.com o super@demo.com (cualquier contraseña).';

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
  /// `false` si falta confirmar el correo con el enlace que llega por email.
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
      emailRedirectTo: _webOrigin,
    );

    if (isObfuscatedExistingUser(hasSession: res.session != null, identities: res.user?.identities)) {
      throw AuthException('User already registered', code: 'user_already_exists');
    }
    return res.session != null;
  }

  /// Con confirmación de correo activa, Supabase NO devuelve error si el correo ya
  /// existe (anti-enumeración): responde "éxito" con un usuario SIN identidades y sin
  /// sesión. Con confirmación desactivada sí lanza `user_already_exists`. Un éxito de
  /// `signUp` por sí solo no prueba que se haya creado una cuenta nueva.
  static bool isObfuscatedExistingUser({required bool hasSession, required List<UserIdentity>? identities}) =>
      !hasSession && identities != null && identities.isEmpty;

  /// Longitud mínima de contraseña aprobada para todos los roles. El servidor
  /// debe exigir lo mismo (Authentication → Providers → Email → Minimum length).
  static const int minPasswordLength = 8;

  /// Reglas de contraseña NUEVA: solo longitud (se permiten frases con espacios).
  static String? newPasswordProblem(String? value) {
    if (value == null || value.isEmpty) return 'Crea una contraseña';
    if (value.length < minPasswordLength) return 'Mínimo $minPasswordLength caracteres';
    if (value.length > 72) return 'Máximo 72 caracteres';
    return null;
  }

  /// Verifica el código OTP del registro. Si es correcto, Supabase crea la sesión.
  static Future<void> verifySignupCode(String email, String code) async {
    if (kDemo) throw AuthException(_demoOnly);
    await _auth.verifyOTP(type: OtpType.signup, email: email.trim(), token: code.trim());
  }

  /// Segundos que el servidor pide esperar antes de reenviar, si lo informa.
  static int? retryAfterSeconds(Object error) {
    if (error is! AuthException) return null;
    final m = RegExp(r'after (\d+) seconds?').firstMatch(error.message);
    return m == null ? null : int.parse(m.group(1)!);
  }

  /// En web, el enlace del correo vuelve al mismo sitio desde el que se
  /// registró (debe estar en Authentication → URL Configuration → Redirect
  /// URLs; si no, Supabase usa el Site URL). En móvil usa el Site URL.
  static String? get _webOrigin => kIsWeb ? Uri.base.origin : null;

  /// Reenvía el correo con el enlace de confirmación.
  static Future<void> resendSignupLink(String email) async {
    await _auth.resend(
      type: OtpType.signup,
      email: email.trim(),
      emailRedirectTo: _webOrigin,
    );
  }

  /// Intenta iniciar sesión para saber si el correo ya fue confirmado.
  /// Devuelve `true` si entró (el listener de `main.dart` navega al panel) y
  /// `false` si el correo sigue sin confirmar. Cualquier otro error se propaga.
  static Future<bool> tryConfirmedSignIn({required String email, required String password}) async {
    try {
      await _auth.signInWithPassword(email: email.trim(), password: password);
      return true;
    } on AuthException catch (e) {
      if (e.code == 'email_not_confirmed' ||
          e.message.toLowerCase().contains('email not confirmed')) {
        return false;
      }
      rethrow;
    }
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
