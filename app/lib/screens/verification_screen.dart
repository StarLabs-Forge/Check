import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/errors.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_scaffold.dart';

/// Confirmación de correo por enlace (flujo por defecto de Supabase Auth).
///
/// Supabase manda un correo con un enlace; al abrirlo el correo queda
/// confirmado. Esta pantalla avisa que hay que revisar el correo y, mientras
/// está abierta, consulta cada pocos segundos si ya se confirmó (intentando
/// iniciar sesión con las mismas credenciales). Al confirmarse, Supabase crea
/// la sesión y el listener de `main.dart` lleva al panel.
///
/// Si no se recibe la contraseña (`password == null`) no se puede consultar
/// solo: queda el botón para volver a iniciar sesión.
///
/// Nota: esto es verificación de correo, NO un 2FA en cada login. Un 2FA real
/// requeriría Supabase MFA (TOTP).
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key, required this.email, this.password});

  final String email;
  final String? password;

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  static const _resendSeconds = 60;
  // Supabase limita los inicios de sesión por IP: 15 s deja margen de sobra.
  static const _pollEvery = Duration(seconds: 15);
  static const _pollMax = Duration(minutes: 10);

  Timer? _resendTimer;
  Timer? _pollTimer;
  int _secondsLeft = _resendSeconds;
  bool _checking = false;
  bool _gaveUp = false;
  String? _error;
  final Stopwatch _watch = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    if (widget.password != null) {
      _pollTimer = Timer.periodic(_pollEvery, (_) => _check(silent: true));
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        if (mounted) setState(() => _secondsLeft = 0);
      } else {
        if (mounted) setState(() => _secondsLeft -= 1);
      }
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Revisa si el correo ya fue confirmado. Si lo está, el inicio de sesión
  /// crea la sesión y el listener de auth navega al panel.
  Future<void> _check({bool silent = false}) async {
    final password = widget.password;
    if (password == null || _checking) return;

    if (_watch.elapsed > _pollMax) {
      _pollTimer?.cancel();
      if (mounted) setState(() => _gaveUp = true);
      if (silent) return;
    }

    setState(() {
      _checking = true;
      if (!silent) _error = null;
    });
    try {
      final confirmed = await AuthService.tryConfirmedSignIn(
        email: widget.email,
        password: password,
      );
      if (!mounted) return;
      if (!confirmed && !silent) {
        setState(() => _error = 'Todavía no vemos la confirmación. Abre el enlace del correo y vuelve aquí.');
      }
    } catch (e) {
      if (!mounted) return;
      _pollTimer?.cancel();
      setState(() => _error = friendlyError(e));
    }
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0) return;
    try {
      await AuthService.resendSignupLink(widget.email);
      if (!mounted) return;
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Correo reenviado')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPoll = widget.password != null;
    return AuthScaffold(
      title: 'Revisa tu correo',
      subtitle: 'Enviamos un enlace de confirmación a ${widget.email}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.mark_email_unread_outlined, size: 56, color: AppColors.accentPrimary),
          const SizedBox(height: AppSpacing.s4),
          const Text(
            'Abre el correo y toca el enlace para activar tu cuenta. '
            'Si no lo ves, revisa la carpeta de spam.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
          ),
          const SizedBox(height: AppSpacing.s4),
          if (canPoll && !_gaveUp)
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentPrimary),
                ),
                SizedBox(width: AppSpacing.s2),
                Text(
                  'Esperando tu confirmación…',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.caption),
                ),
              ],
            ),
          if (_gaveUp)
            const Text(
              'Dejamos de esperar. Cuando confirmes el correo, inicia sesión.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.caption),
            ),
          AuthError(_error),
          const SizedBox(height: AppSpacing.s5),
          if (canPoll)
            AuthSubmit(label: 'Ya confirmé mi correo', loading: _checking, onPressed: () => _check()),
          if (!canPoll)
            AuthSubmit(
              label: 'Ir a iniciar sesión',
              loading: false,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          const SizedBox(height: AppSpacing.s4),
          Center(
            child: TextButton(
              onPressed: _secondsLeft == 0 ? _resend : null,
              child: Text(
                _secondsLeft == 0
                    ? 'Reenviar correo'
                    : 'Reenviar correo en ${_secondsLeft}s',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
