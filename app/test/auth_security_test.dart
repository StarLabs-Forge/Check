import 'package:check/screens/mfa_screen.dart';
import 'package:check/screens/verification_screen.dart';
import 'package:check/services/app_session.dart';
import 'package:check/services/auth_service.dart';
import 'package:check/services/mfa_service.dart';
import 'package:check/theme/app_theme.dart';
import 'package:check/widgets/role_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

Future<void> _pump(WidgetTester t, Widget home, {Map<String, WidgetBuilder> routes = const {}}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  // Ancho de tableta: sin panel lateral (la fuente de pruebas es mucho más ancha que Inter).
  t.view.physicalSize = const Size(700, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(theme: AppTheme.dark, home: home, routes: routes));
  await t.pump(const Duration(seconds: 2));
}

class _FakeMfa extends MfaService {
  _FakeMfa({this.existing});
  final String? existing;
  final codes = <String>[];
  var enrollments = 0;

  @override
  Future<String?> verifiedFactorId() async => existing;
  @override
  Future<TotpEnrollment> enroll() async {
    enrollments++;
    return const TotpEnrollment(factorId: 'nuevo', uri: 'otpauth://totp/CHECK:x?secret=ABC', secret: 'CLAVEPRUEBA');
  }

  @override
  Future<void> verify(String factorId, String code) async {
    codes.add('$factorId:$code');
    if (code != '123456') throw AuthException('Invalid TOTP code entered', code: 'mfa_verification_failed');
  }
}

void main() {
  group('política de contraseñas', () {
    test('mínimo 8, admite frases y rechaza más de 72', () {
      expect(AuthService.newPasswordProblem('1234567'), contains('8'));
      expect(AuthService.newPasswordProblem('12345678'), isNull);
      expect(AuthService.newPasswordProblem('una frase larga con espacios'), isNull);
      expect(AuthService.newPasswordProblem('x' * 73), contains('72'));
    });
  });

  group('verificación OTP', () {
    testWidgets('pegar con espacios deja solo dígitos y verifica una vez', (t) async {
      final calls = <String>[];
      await _pump(t, VerificationScreen(email: 'a@example.com', verify: (e, c) async => calls.add('$e|$c')));
      await t.enterText(find.byType(TextField), '12 34-56');
      await t.tap(find.text('Verificar código'));
      await t.pump();
      expect(calls, ['a@example.com|123456']);
    });

    testWidgets('código corto no llama al servidor', (t) async {
      var calls = 0;
      await _pump(t, VerificationScreen(email: 'a@example.com', verify: (_, _) async => calls++));
      await t.enterText(find.byType(TextField), '123');
      await t.tap(find.text('Verificar código'));
      await t.pump();
      expect(calls, 0);
      expect(find.textContaining('código completo'), findsOneWidget);
    });

    testWidgets('código incorrecto o vencido muestra el motivo', (t) async {
      await _pump(t, VerificationScreen(
        email: 'a@example.com',
        verify: (_, _) async => throw AuthException('Token has expired or is invalid', code: 'otp_expired'),
      ));
      await t.enterText(find.byType(TextField), '000000');
      await t.tap(find.text('Verificar código'));
      await t.pump(const Duration(seconds: 1));
      expect(find.text('El código es incorrecto o ya venció.'), findsOneWidget);
    });

    testWidgets('reenvío: espera el contador y respeta el límite del servidor', (t) async {
      var sends = 0;
      await _pump(t, VerificationScreen(
        email: 'a@example.com',
        resend: (_) async {
          sends++;
          throw AuthException('For security purposes, you can only request this after 42 seconds.',
              code: 'over_email_send_rate_limit');
        },
      ));
      expect(find.textContaining('Reenviar código en'), findsOneWidget);
      await t.tap(find.textContaining('Reenviar código en'));
      expect(sends, 0);
      await t.pump(const Duration(seconds: 61));
      await t.tap(find.text('Reenviar código'));
      await t.pump();
      expect(sends, 1);
      expect(find.text('Reenviar código en 42s'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('MFA', () {
    testWidgets('sin factor: muestra QR, oculta la clave y activa con código válido', (t) async {
      final mfa = _FakeMfa();
      var entered = false;
      await _pump(t, MfaScreen(service: mfa, onVerified: (_) async => entered = true));
      expect(find.text('Configura tu autenticador'), findsOneWidget);
      expect(find.text('CLAVEPRUEBA'), findsNothing);
      await t.enterText(find.byType(TextField), '999999');
      await t.tap(find.text('Activar y continuar'));
      await t.pump(const Duration(seconds: 1));
      expect(entered, isFalse);
      expect(find.textContaining('autenticador no es correcto'), findsOneWidget);
      await t.enterText(find.byType(TextField), '123456');
      await t.tap(find.text('Activar y continuar'));
      await t.pump(const Duration(seconds: 1));
      expect(entered, isTrue);
      expect(mfa.codes, ['nuevo:999999', 'nuevo:123456']);
    });

    testWidgets('con factor: pide código sin volver a dar de alta', (t) async {
      final mfa = _FakeMfa(existing: 'f1');
      await _pump(t, MfaScreen(service: mfa, onVerified: (_) async {}));
      expect(find.text('Verificación en dos pasos'), findsOneWidget);
      expect(mfa.enrollments, 0);
    });

    test('respuesta del servidor → sesión pendiente', () {
      expect(AppSession.mfaPendingFrom({'required': true, 'satisfied': false}), isTrue);
      expect(AppSession.mfaPendingFrom({'required': true, 'satisfied': true}), isFalse);
      expect(AppSession.mfaPendingFrom({'required': false, 'satisfied': true}), isFalse);
      expect(AppSession.mfaPendingFrom(null), isFalse);
    });

    testWidgets('RoleGuard envía a /mfa una sesión privilegiada sin segundo factor', (t) async {
      AppSession.profile.value = const Profile(
        id: 'x', fullName: 'A', role: 'admin', plan: 'pro', status: 'active', venueName: 'L', mfaPending: true,
      );
      addTearDown(AppSession.clear);
      expect(AppSession.entryRoute, '/mfa');
      await _pump(t, const RoleGuard(roles: {'admin'}, child: Text('panel privado')),
          routes: {'/mfa': (_) => const Scaffold(body: Text('pantalla mfa'))});
      await t.pump(const Duration(seconds: 1));
      expect(find.text('panel privado'), findsNothing);
      expect(find.text('pantalla mfa'), findsOneWidget);
    });
  });
}
