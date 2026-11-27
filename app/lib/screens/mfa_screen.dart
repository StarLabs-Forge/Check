import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/app_session.dart';
import '../services/auth_service.dart';
import '../services/errors.dart';
import '../services/mfa_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_scaffold.dart';

/// Segundo factor obligatorio para administradores y superadministradores.
///
/// Sin factor verificado → alta con QR. Con factor → pide el código. Hasta
/// completarlo, el servidor no entrega datos ni acepta operaciones privilegiadas.
class MfaScreen extends StatefulWidget {
  const MfaScreen({super.key, this.service = const MfaService(), this.onVerified, this.onSignOut});

  final MfaService service;

  /// Por defecto recarga la sesión y va al panel del rol.
  final Future<void> Function(BuildContext context)? onVerified;
  final Future<void> Function()? onSignOut;

  @override
  State<MfaScreen> createState() => _MfaScreenState();
}

class _MfaScreenState extends State<MfaScreen> {
  final _code = TextEditingController();
  String? _factorId;
  TotpEnrollment? _enrollment;
  bool _loading = true;
  bool _busy = false;
  bool _showSecret = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final existing = await widget.service.verifiedFactorId();
      TotpEnrollment? enrollment;
      if (existing == null) enrollment = await widget.service.enroll();
      if (!mounted) return;
      setState(() {
        _factorId = existing ?? enrollment!.factorId;
        _enrollment = enrollment;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    final id = _factorId;
    if (_busy || id == null) return;
    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'El código del autenticador tiene 6 dígitos.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.verify(id, code);
      if (!mounted) return;
      await (widget.onVerified ?? _enter)(context);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _enter(BuildContext context) async {
    final problem = await AppSession.load();
    if (!context.mounted || problem != null) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppSession.entryRoute, (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final enrolling = _enrollment != null;
    return AuthScaffold(
      title: enrolling ? 'Configura tu autenticador' : 'Verificación en dos pasos',
      subtitle: enrolling
          ? 'Tu cuenta requiere un segundo factor. Escanea el código con Google Authenticator, Microsoft Authenticator o Aegis.'
          : 'Escribe el código de tu aplicación autenticadora.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator(color: AppColors.accentPrimary))
          else ...[
            if (enrolling) ...[
              Center(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(AppSpacing.s2),
                  child: QrImageView(data: _enrollment!.uri, size: 168, semanticsLabel: 'Código QR del autenticador'),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _showSecret = !_showSecret),
                  child: Text(_showSecret ? 'Ocultar clave' : '¿No puedes escanear? Ver clave manual'),
                ),
              ),
              if (_showSecret)
                SelectableText(
                  _enrollment!.secret,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textPrimary, letterSpacing: 2),
                ),
              const SizedBox(height: AppSpacing.s3),
            ],
            if (_factorId != null)
              TextField(
                controller: _code,
                autofocus: true,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, letterSpacing: 8),
                decoration: const InputDecoration(labelText: 'Código de 6 dígitos'),
                onSubmitted: (_) => _submit(),
              ),
            AuthError(_error),
            const SizedBox(height: AppSpacing.s4),
            if (_factorId != null)
              AuthSubmit(label: enrolling ? 'Activar y continuar' : 'Verificar', loading: _busy, onPressed: _submit)
            else
              AuthSubmit(label: 'Reintentar', loading: false, onPressed: _prepare),
          ],
          const SizedBox(height: AppSpacing.s3),
          const Text(
            'Si perdiste tu autenticador, contacta al equipo de CHECK para restablecerlo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.caption),
          ),
          Center(
            child: TextButton(
              onPressed: _busy ? null : () => (widget.onSignOut ?? AuthService.signOut)(),
              child: const Text('Cerrar sesión'),
            ),
          ),
        ],
      ),
    );
  }
}
