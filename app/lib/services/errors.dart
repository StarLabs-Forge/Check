import 'package:supabase_flutter/supabase_flutter.dart';

/// Traduce errores de Supabase (Auth / Postgres / red) a mensajes para el
/// usuario. Los códigos `plan_limit_*`, `event_closed`, etc. salen de las
/// funciones y triggers del schema (ver `guard_event`, `create_ticket`).
String friendlyError(Object error) {
  if (error is AuthException) return _authMessage(error);
  if (error is PostgrestException) return _postgrestMessage(error);

  final text = error.toString();
  if (text.contains('capacity_below_sold')) return 'La capacidad no puede ser menor a las entradas ya vendidas o reservadas.';
  if (text.contains('price_locked_with_sales')) return 'No puedes cambiar el precio ni el tipo de acceso: ya hay entradas vendidas.';
  if (text.contains('invalid_dates')) return 'La hora de fin debe ser posterior a la de inicio.';
  if (text.contains('event_locked')) return 'Un evento finalizado o suspendido no se puede modificar.';
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
    return 'Si ya tienes una cuenta con este correo, inicia sesión para continuar.';
  }
  if (code == 'weak_password' || msg.contains('password should be')) {
    return 'La contraseña es muy débil. Usa al menos 8 caracteres y evita contraseñas conocidas.';
  }
  if (code == 'mfa_verification_failed' || msg.contains('invalid totp')) {
    return 'El código del autenticador no es correcto. Revisa que la hora del teléfono sea automática.';
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
  if (m.contains('capacity_below_sold')) return 'La capacidad no puede ser menor a las entradas ya vendidas o reservadas.';
  if (m.contains('price_locked_with_sales')) return 'No puedes cambiar el precio ni el tipo de acceso: ya hay entradas vendidas.';
  if (m.contains('invalid_dates')) return 'La hora de fin debe ser posterior a la de inicio.';
  if (m.contains('reason_required')) return 'Indica el motivo del cambio.';
  if (m.contains('draft_blocked_sales')) return 'No se puede volver a borrador: el evento ya tiene entradas vendidas.';
  if (m.contains('draft_blocked_used_qr')) return 'No se puede volver a borrador: ya hay ingresos registrados con QR.';
  if (m.contains('event_inactive')) return 'El evento no está activo: las entradas todavía no permiten ingresar.';
  if (m.contains('commercial_inactive')) return 'Tu local no tiene una prueba vigente ni un plan activo. Activa la prueba gratuita o contrata un plan.';
  if (m.contains('ticket_type_required')) return 'Elige la categoría de la entrada. Si no aparece, actualiza la aplicación.';
  if (m.contains('invalid_ticket_type')) return 'Esa categoría no está disponible.';
  if (m.contains('category_capacity_exceeds_event')) return 'La suma de cupos de las categorías supera el aforo del evento. Reduce otra categoría primero.';
  if (m.contains('category_has_history')) return 'Esta categoría ya tiene pedidos o entradas: desactívala en lugar de eliminarla.';
  if (m.contains('sold_out')) return 'No quedan cupos disponibles en esa categoría o en el evento.';
  if (m.contains('trial_already_used')) return 'Este local ya usó su prueba gratuita.';
  if (m.contains('payment_note_required')) return 'Describe cómo verificaste el pago.';
  if (m.contains('plan_not_active')) return 'El local no tiene un plan activo.';
  if (m.contains('target_not_admin')) return 'Solo se puede restablecer el MFA de un administrador de local.';
  if (m.contains('venue_required')) return 'Completa los datos de tu local antes de activar la prueba gratuita.';
  if (m.contains('too_many_open_orders')) return 'Este teléfono ya tiene 3 pedidos activos.';
  if (m.contains('invalid_status_transition')) return 'Ese cambio de estado no está permitido.';
  if (m.contains('invalid_guest_name')) return 'El nombre del invitado no es válido.';
  if (m.contains('ticket_not_payable')) return 'Ese ticket ya no se puede marcar como pagado.';
  if (m.contains('ticket_not_cancellable')) return 'Ese ticket ya no se puede cancelar.';
  if (m.contains('forbidden') || e.code == '42501') return 'No tienes permiso para hacer esto.';
  if (e.code == '23503') return 'Esta categoría ya tiene pedidos o entradas: desactívala en lugar de eliminarla.';
  if (e.code == '23514') return 'Hay un dato fuera de rango. Revisa los campos.';
  return 'No se pudo completar la operación. Intenta de nuevo.';
}
