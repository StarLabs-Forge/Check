import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/errors.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_scaffold.dart';

/// Confirmación de correo con el código OTP nativo de Supabase Auth.
///
/// Requiere que la plantilla «Confirm signup» del proyecto use `{{ .Token }}`
/// (Authentication → Email Templates). La longitud y la vigencia del código las
/// fija la configuración del proyecto; el servidor es quien lo valida. Al
/// verificar, Supabase crea la sesión y el listener de `main.dart` navega.
///
/// Mientras la plantilla antigua (enlace) siga activa, «Ya confirmé con el
/// enlace» permite entrar si el registro entregó la contraseña.
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key, required this.email, this.password, this.verify, this.resend});

  final String email;
  final String? password;

  /// Inyectables para pruebas; por defecto usan [AuthService].
  final Future<void> Function(String email, String code)? verify;
  final Future<void> Function(String email)? resend;

  static const minCodeLength = 6;
  static const maxCodeLength = 10;

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  /// Espera por defecto de Supabase entre correos al mismo destinatario. Si el
  /// servidor pide otra, se usa la que informa en el error.
  static const _resendSeconds = 60;

  final _code = TextEditingController();
  Timer? _resendTimer;
  int _secondsLeft = _resendSeconds;
  bool _verifying = false;
  bool _resending = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _startResendTimer(_resendSeconds);
  }

  void _startResendTimer(int seconds) {
    _resendTimer?.cancel();
    setState(() => _secondsLeft = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _secondsLeft -= 1);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_verifying) return;
    final code = _code.text.trim();
    if (code.length < VerificationScreen.minCodeLength) {
      setState(() => _error = 'Escribe el código completo que llegó a tu correo.');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
      _notice = null;
    });
    try {
      await (widget.verify ?? AuthService.verifySignupCode)(widget.email, code);
      if (mounted) setState(() => _notice = 'Correo confirmado. Entrando…');
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
    if (mounted) setState(() => _verifying = false);
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0 || _resending) return;
    setState(() {
      _resending = true;
      _error = null;
      _notice = null;
    });
    try {
      await (widget.resend ?? AuthService.resendSignupLink)(widget.email);
      if (!mounted) return;
      _startResendTimer(_resendSeconds);
      setState(() => _notice = 'Enviamos un código nuevo. El anterior deja de servir.');
    } catch (e) {
      if (!mounted) return;
      final wait = AuthService.retryAfterSeconds(e);
      if (wait != null) _startResendTimer(wait);
      setState(() => _error = friendlyError(e));
    }
    if (mounted) setState(() => _resending = false);
  }

  Future<void> _useLink() async {
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final ok = await AuthService.tryConfirmedSignIn(email: widget.email, password: widget.password!);
      if (!ok && mounted) setState(() => _error = 'Todavía no vemos la confirmación.');
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
    if (mounted) setState(() => _verifying = false);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Verifica tu correo',
      subtitle: 'Enviamos un código a ${widget.email}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Escribe o pega el código para activar tu cuenta. Si no lo ves, revisa la carpeta de spam.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
          ),
          const SizedBox(height: AppSpacing.s4),
          TextField(
            controller: _code,
            autofocus: true,
            enabled: !_verifying,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            textAlign: TextAlign.center,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly, // pegar «123 456» deja solo los dígitos
              LengthLimitingTextInputFormatter(VerificationScreen.maxCodeLength),
            ],
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, letterSpacing: 6),
            decoration: const InputDecoration(labelText: 'Código de verificación'),
            onSubmitted: (_) => _verify(),
          ),
          AuthError(_error),
          if (_notice != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s2),
              child: Text(_notice!, style: const TextStyle(color: AppColors.accentPrimary, fontSize: AppTextSize.caption)),
            ),
          const SizedBox(height: AppSpacing.s5),
          AuthSubmit(label: 'Verificar código', loading: _verifying, onPressed: _verify),
          const SizedBox(height: AppSpacing.s3),
          Center(
            child: TextButton(
              onPressed: _secondsLeft <= 0 && !_resending ? _resend : null,
              child: Text(_secondsLeft <= 0 ? 'Reenviar código' : 'Reenviar código en ${_secondsLeft}s'),
            ),
          ),
          if (widget.password != null)
            Center(
              child: TextButton(
                onPressed: _verifying ? null : _useLink,
                child: const Text('Ya confirmé con el enlace del correo'),
              ),
            ),
        ],
      ),
    );
  }
}
