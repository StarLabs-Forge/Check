import 'package:supabase_flutter/supabase_flutter.dart';

/// Traduce errores de Supabase (Auth / Postgres / red) a mensajes para el
/// usuario. Los códigos `plan_limit_*`, `event_closed`, etc. salen de las
/// funciones y triggers del schema (ver `guard_event`, `create_ticket`).
String friendlyError(Object error) {
  if (error is AuthException) return _authMessage(error);
  if (error is PostgrestException) return _postgrestMessage(error);

  final text = error.toString();
  if (text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup') ||
      text.contains('XMLHttpRequest')) {
    return 'No hay conexión con el servidor. Revisa tu internet e intenta de nuevo.';
  }
  return 'Ocurrió un error inesperado. Intenta de nuevo.';
}

String _authMessage(AuthException e) {
  final code = e.code ?? '';
  final msg = e.message.toLowerCase();

  if (code == 'invalid_credentials' || msg.contains('invalid login credentials')) {
    return 'Correo o contraseña incorrectos.';
  }
  if (code == 'email_not_confirmed' || msg.contains('email not confirmed')) {
    return 'Confirma tu correo antes de ingresar.';
  }
  if (code == 'user_already_exists' || msg.contains('already registered')) {
    return 'Ese correo ya está registrado.';
  }
  if (code == 'weak_password' || msg.contains('password should be')) {
    return 'La contraseña es muy débil. Usa al menos 6 caracteres.';
  }
  if (code == 'otp_expired' || msg.contains('expired') || msg.contains('invalid') && msg.contains('token')) {
    return 'El código es incorrecto o ya venció.';
  }
  if (code == 'over_email_send_rate_limit' || code == 'over_request_rate_limit' || msg.contains('rate limit')) {
    return 'Demasiados intentos. Espera un momento e intenta de nuevo.';
  }
  if (code == 'provider_disabled' || msg.contains('provider is not enabled')) {
    return 'Ese método de acceso todavía no está habilitado.';
  }
  return 'No se pudo completar la autenticación. Intenta de nuevo.';
}

String _postgrestMessage(PostgrestException e) {
  final m = e.message;

  if (m.contains('plan_limit_events')) {
    return 'Tu plan no permite más eventos en ese mes. Mejora tu plan para crear más.';
  }
  if (m.contains('plan_limit_tickets')) {
    return 'Alcanzaste el límite de QR de tu plan este mes.';
  }
  if (m.contains('event_closed')) return 'El evento ya está cerrado: no se pueden emitir tickets.';
  if (m.contains('event_locked')) return 'Un evento finalizado o suspendido no se puede modificar.';
  if (m.contains('invalid_status_transition')) return 'Ese cambio de estado no está permitido.';
  if (m.contains('invalid_guest_name')) return 'El nombre del invitado no es válido.';
  if (m.contains('ticket_not_payable')) return 'Ese ticket ya no se puede marcar como pagado.';
  if (m.contains('ticket_not_cancellable')) return 'Ese ticket ya no se puede cancelar.';
  if (m.contains('forbidden') || e.code == '42501') return 'No tienes permiso para hacer esto.';
  if (e.code == '23514') return 'Hay un dato fuera de rango. Revisa los campos.';
  return 'No se pudo completar la operación. Intenta de nuevo.';
}
