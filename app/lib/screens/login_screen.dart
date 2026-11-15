import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/errors.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_scaffold.dart';
import 'register_screen.dart';
import 'verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Ingresa tu correo';
    final regex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    if (!regex.hasMatch(email)) return 'Correo inválido';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Ingresa tu contraseña';
    if (value.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final email = _emailController.text.trim();
    try {
      // Si sale bien, el listener de auth (main.dart) carga el perfil y
      // navega al panel; acá no hay que hacer nada más.
      await AuthService.signIn(email: email, password: _passwordController.text);
    } on AuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'email_not_confirmed') {
        // Cuenta creada pero sin confirmar: reenvía el código y pide verificarlo.
        try {
          await AuthService.resendSignupCode(email);
        } catch (_) {}
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => VerificationScreen(email: email)),
        );
        return;
      }
      setState(() => _error = friendlyError(e));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
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

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Inicia sesión',
      subtitle: 'Gestiona tus eventos y el acceso de tu staff',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                hintText: 'tu@local.com',
              ),
              validator: _validateEmail,
            ),
            const SizedBox(height: AppSpacing.s4),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              style: const TextStyle(color: AppColors.textPrimary),
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Contraseña',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: _validatePassword,
            ),
            const SizedBox(height: AppSpacing.s2),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Recuperación de contraseña — próximamente')),
                  );
                },
                child: const Text('¿Olvidaste tu contraseña?'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.s2),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: AppTextSize.caption),
              ),
            ],
            const SizedBox(height: AppSpacing.s4),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.bgPrimary,
                      ),
                    )
                  : const Text('Iniciar sesión'),
            ),
            const SizedBox(height: AppSpacing.s6),
            const OrDivider(),
            const SizedBox(height: AppSpacing.s6),
            GoogleButton(
              label: 'Continuar con Google',
              onPressed: _isSubmitting ? null : _continueWithGoogle,
            ),
            const SizedBox(height: AppSpacing.s6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '¿No tienes cuenta?',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    );
                  },
                  child: const Text('Regístrate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
