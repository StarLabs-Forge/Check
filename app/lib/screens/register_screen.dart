import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_scaffold.dart';
import 'verification_screen.dart';

/// Registro — exclusivo para el Admin/Organizador. El Staff nunca pasa por
/// esta pantalla: recibe acceso por código de parte del Admin (ver
/// VerificationScreen / flujo de staff, pendiente de pantalla propia).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

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

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Crea una contraseña';
    if (value.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }

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

    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VerificationScreen(email: _emailController.text.trim()),
      ),
    );
  }

  void _continueWithGoogle() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const VerificationScreen(email: 'tu cuenta de Google'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Crea tu cuenta',
      subtitle: 'Registra tu local y empieza a gestionar tus eventos',
      maxWidth: 460,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Nombre completo'),
              validator: (v) => _required(v, 'Ingresa tu nombre'),
            ),
            const SizedBox(height: AppSpacing.s4),
            TextFormField(
              controller: _venueController,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Nombre del local u organización',
                hintText: 'Ej. Dharma Club',
              ),
              validator: (v) => _required(v, 'Ingresa el nombre de tu local'),
            ),
            const SizedBox(height: AppSpacing.s4),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Correo electrónico'),
              validator: _validateEmail,
            ),
            const SizedBox(height: AppSpacing.s4),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: AppColors.textPrimary),
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
            const SizedBox(height: AppSpacing.s4),
            TextFormField(
              controller: _confirmController,
              obscureText: _obscureConfirm,
              textInputAction: TextInputAction.done,
              style: const TextStyle(color: AppColors.textPrimary),
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Confirmar contraseña',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: _validateConfirm,
            ),
            const SizedBox(height: AppSpacing.s4),
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
            const SizedBox(height: AppSpacing.s6),
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
                  : const Text('Crear cuenta'),
            ),
            const SizedBox(height: AppSpacing.s6),
            const OrDivider(),
            const SizedBox(height: AppSpacing.s6),
            GoogleButton(
              label: 'Registrarme con Google',
              onPressed: _isSubmitting ? null : _continueWithGoogle,
            ),
            const SizedBox(height: AppSpacing.s6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '¿Ya tienes cuenta?',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
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
