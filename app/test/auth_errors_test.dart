import 'package:check/services/errors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('un registro existente orienta al inicio de sesión', () {
    final message = friendlyError(
      const AuthException('User already registered', code: 'user_already_exists'),
    );
    expect(message, contains('inicia sesión'));
    expect(message, contains('Si ya tienes una cuenta'));
  });
}
