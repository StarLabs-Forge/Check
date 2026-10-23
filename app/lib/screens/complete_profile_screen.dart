import 'package:flutter/material.dart';
import '../services/app_session.dart';
import '../services/auth_service.dart';
import '../services/errors.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_scaffold.dart';

/// Se muestra tras entrar con Google cuando faltan los datos que el registro
/// con correo ya pide (nombre del local). Nombre y correo vienen de Google.
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final _venueController = TextEditingController();

  bool _acceptedTerms = false;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = AppSession.profile.value;
    _nameController = TextEditingController(text: profile?.fullName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _venueController.dispose();
    super.dispose();
  }

  String? _required(String? value, String message) {
    if (value == null || value.trim().isEmpty) return message;
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
    });

    try {
      await AuthService.completeProfile(
        fullName: _nameController.text,
        venueName: _venueController.text,
      );
      final error = await AppSession.load();
      if (!mounted) return;
      if (error != null) {
        setState(() => _error = error);
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        return;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    }

    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Completa tu perfil',
      subtitle: 'Un último paso para registrar tu local',
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
              textInputAction: TextInputAction.done,
              style: const TextStyle(color: AppColors.textPrimary),
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Nombre del local u organización',
                hintText: 'Ej. Dharma Club',
              ),
              validator: (v) => _required(v, 'Ingresa el nombre de tu local'),
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
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.s3),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: AppTextSize.caption),
              ),
            ],
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
                  : const Text('Continuar'),
            ),
            const SizedBox(height: AppSpacing.s3),
            TextButton(
              onPressed: _isSubmitting ? null : AuthService.signOut,
              child: const Text('Cancelar y cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}
