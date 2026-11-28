import 'package:flutter_test/flutter_test.dart';
import 'package:check/services/errors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('mensajes de los errores de la migración 14', () {
    expect(friendlyError(const PostgrestException(message: 'reason_required')), contains('motivo'));
    expect(friendlyError(const PostgrestException(message: 'venue_required')), contains('local'));
    expect(friendlyError(const PostgrestException(message: 'too_many_open_orders')), contains('3 pedidos'));
    for (final code in [
      'schema_outdated', 'draft_blocked_sales', 'draft_blocked_used_qr', 'event_inactive', 'commercial_inactive',
      'ticket_type_required', 'invalid_ticket_type', 'category_capacity_exceeds_event', 'category_has_history',
      'sold_out', 'trial_already_used', 'payment_note_required', 'plan_not_active', 'target_not_admin',
    ]) {
      expect(friendlyError(PostgrestException(message: code)), isNot(contains('No se pudo completar')), reason: code);
    }
  });
}
