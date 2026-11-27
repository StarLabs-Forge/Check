import 'package:supabase_flutter/supabase_flutter.dart';

/// Alta en curso de un autenticador TOTP. El secreto solo vive en memoria
/// mientras se muestra la pantalla: no se guarda ni se registra en logs.
class TotpEnrollment {
  const TotpEnrollment({required this.factorId, required this.uri, required this.secret});
  final String factorId;
  final String uri;
  final String secret;
}

/// MFA nativo de Supabase (TOTP). El servidor exige `aal2` por RLS y RPC; esta
/// clase solo conduce el alta y la verificación.
class MfaService {
  const MfaService();

  GoTrueMFAApi get _mfa => Supabase.instance.client.auth.mfa;

  /// Id del factor TOTP verificado, o `null` si falta configurarlo.
  Future<String?> verifiedFactorId() async {
    final factors = await _mfa.listFactors();
    return factors.totp.isEmpty ? null : factors.totp.first.id;
  }

  Future<TotpEnrollment> enroll() async {
    // Un alta abandonada deja un factor sin verificar que bloquearía la nueva.
    final factors = await _mfa.listFactors();
    for (final f in factors.all) {
      if (f.factorType == FactorType.totp && f.status == FactorStatus.unverified) {
        await _mfa.unenroll(f.id);
      }
    }
    final res = await _mfa.enroll(factorType: FactorType.totp, issuer: 'CHECK');
    return TotpEnrollment(factorId: res.id, uri: res.totp!.uri, secret: res.totp!.secret);
  }

  /// Verifica el código y sube la sesión a `aal2`.
  Future<void> verify(String factorId, String code) async {
    await _mfa.challengeAndVerify(factorId: factorId, code: code);
  }
}
