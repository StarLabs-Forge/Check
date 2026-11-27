import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/demo_mode.dart';
import '../services/app_session.dart';
import '../services/auth_service.dart';
import '../services/errors.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_scaffold.dart';
import 'verification_screen.dart';

/// Registro — exclusivo para el Admin/Organizador. El Staff nunca pasa por
/// esta pantalla: recibe acceso por código de parte del Admin (ver
/// VerificationScreen / flujo de staff, pendiente de pantalla propia).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.origin});

  /// Contexto con el que se llegó (`/registro?origen=prueba|demo`). Solo informa:
  /// NO activa la prueba ni cambia permisos; la prueba se activa en el panel.
  final String? origin;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _venueController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _acceptedTerms = false;
  bool _isSubmitting = false;
  String? _error;
  bool _existingAccount = false;

  static bool get _hasActiveSession {
    if (kDemo) return false;
    try {
      return Supabase.instance.client.auth.currentSession != null;
    } catch (_) {
      return false; // Supabase sin inicializar (pruebas de componentes)
    }
  }

  @override
  void initState() {
    super.initState();
    // Con sesión activa no hay nada que registrar: va directo a su panel
    // (el rol sale del perfil en la base, no de la URL ni del cliente).
    if (_hasActiveSession) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (AppSession.profile.value == null) await AppSession.load();
        if (!mounted || AppSession.profile.value == null) return;
        Navigator.of(context).pushNamedAndRemoveUntil(AppSession.entryRoute, (r) => false);
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _venueController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _required(String? value, String message) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Ingresa tu correo';
    final regex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    if (!regex.hasMatch(email)) return 'Correo inválido';
    return null;
  }

  String? _validatePassword(String? value) => AuthService.newPasswordProblem(value);

  String? _validateConfirm(String? value) {
    if (value != _passwordController.text) return 'Las contraseñas no coinciden';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes aceptar los términos para continuar')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
      _existingAccount = false;
    });

    final email = _emailController.text.trim();
    try {
      final hasSession = await AuthService.signUp(
        fullName: _nameController.text,
        venueName: _venueController.text,
        email: email,
        password: _passwordController.text,
      );
      if (!mounted) return;
      // Con sesión → el listener de auth (main.dart) navega al panel.
      // Sin sesión → falta confirmar el correo con el enlace que llegó.
      if (!hasSession) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VerificationScreen(
              email: email,
              password: _passwordController.text,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _existingAccount = e is AuthException &&
            (e.code == 'user_already_exists' || e.message.toLowerCase().contains('already registered'));
      });
    }

    if (mounted) setState(() => _isSubmitting = false);
  }

  Future<void> _continueWithGoogle() async {
    setState(() => _error = null);
    try {
      await AuthService.signInWithGoogle();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    }
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
    TextInputAction action = TextInputAction.next,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      textInputAction: action,
      style: const TextStyle(color: AppColors.textPrimary),
      onFieldSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: AppColors.textSecondary,
          ),
          onPressed: onToggle,
        ),
      ),
      validator: validator,
    );
  }

  String? get _originNote => switch (widget.origin) {
        'prueba' => 'Estás solicitando la prueba gratuita de 14 días. Se activa desde tu panel, una sola vez, cuando completes los datos de tu local.',
        'demo' => kDemo ? 'Estás en la DEMO: los datos son de ejemplo y no se guardan.' : null,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Crea tu cuenta',
      subtitle: 'Registra tu local y empieza a gestionar tus eventos',
      maxWidth: 560,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_originNote != null) ...[
              Text(_originNote!, style: const TextStyle(color: AppColors.accentPrimary, fontSize: AppTextSize.body)),
              const AuthGap(AppSpacing.s3),
            ],
            FieldPair(
              a: TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Nombre completo'),
                validator: (v) => _required(v, 'Ingresa tu nombre'),
              ),
              b: TextFormField(
                controller: _venueController,
                textInputAction: TextInputAction.next,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Local u organización',
                  hintText: 'Ej. Dharma Club',
                ),
                validator: (v) => _required(v, 'Ingresa el nombre de tu local'),
              ),
            ),
            const AuthGap(AppSpacing.s3),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Correo electrónico'),
              validator: _validateEmail,
            ),
            const AuthGap(AppSpacing.s3),
            FieldPair(
              a: _passwordField(
                controller: _passwordController,
                label: 'Contraseña',
                obscure: _obscurePassword,
                onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                validator: _validatePassword,
              ),
              b: _passwordField(
                controller: _confirmController,
                label: 'Confirmar contraseña',
                obscure: _obscureConfirm,
                onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                validator: _validateConfirm,
                action: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
            ),
            const AuthGap(AppSpacing.s3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _acceptedTerms,
                    activeColor: AppColors.accentPrimary,
                    checkColor: AppColors.bgPrimary,
                    side: const BorderSide(color: AppColors.bgBorder),
                    onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
                    child: const Text(
                      'Acepto los términos y condiciones y el manejo de mis datos',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
                    ),
                  ),
                ),
              ],
            ),
            AuthError(_error),
            if (_existingAccount)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/acceso-locales', (route) => false),
                  child: const Text('Iniciar sesión'),
                ),
              ),
            const AuthGap(AppSpacing.s4),
            AuthSubmit(label: 'Crear cuenta', loading: _isSubmitting, onPressed: _submit),
            const AuthGap(AppSpacing.s3),
            const OrDivider(),
            const AuthGap(AppSpacing.s3),
            GoogleButton(
              label: 'Registrarme con Google',
              onPressed: _isSubmitting ? null : _continueWithGoogle,
            ),
            const AuthGap(AppSpacing.s1),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '¿Ya tienes cuenta?',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                    '/acceso-locales',
                    (route) => false,
                  ),
                  child: const Text('Inicia sesión'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
