import 'package:flutter_test/flutter_test.dart';
import 'package:check/services/errors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('mensajes de los errores de la migración 14', () {
    expect(friendlyError(const PostgrestException(message: 'reason_required')), contains('motivo'));
    expect(friendlyError(const PostgrestException(message: 'venue_required')), contains('local'));
    expect(friendlyError(const PostgrestException(message: 'too_many_open_orders')), contains('3 pedidos'));
  });
}
