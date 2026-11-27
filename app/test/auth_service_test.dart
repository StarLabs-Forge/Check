import 'package:check/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show UserIdentity;

void main() {
  group('signUp: ¿cuenta nueva o correo ya registrado?', () {
    test('sin sesión y sin identidades = correo existente (respuesta anti-enumeración)', () {
      expect(AuthService.isObfuscatedExistingUser(hasSession: false, identities: const []), isTrue);
    });
    test('con sesión (confirmación desactivada) = cuenta nueva', () {
      expect(AuthService.isObfuscatedExistingUser(hasSession: true, identities: const []), isFalse);
    });
    test('sin sesión pero con identidades = cuenta nueva pendiente de confirmar correo', () {
      final identity = UserIdentity(
        id: 'i', userId: 'u', identityData: const {}, identityId: 'i', provider: 'email',
        createdAt: '2026-01-01T00:00:00Z', lastSignInAt: '2026-01-01T00:00:00Z',
      );
      expect(AuthService.isObfuscatedExistingUser(hasSession: false, identities: [identity]), isFalse);
    });
    test('identidades desconocidas (null) no se tratan como cuenta existente', () {
      expect(AuthService.isObfuscatedExistingUser(hasSession: false, identities: null), isFalse);
    });
  });
}
