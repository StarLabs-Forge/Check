import 'package:flutter/material.dart';

import '../services/app_session.dart';
import '../theme/app_theme.dart';
import 'check_logo.dart';

/// Protege rutas privadas por rol. NO concede permisos: solo mira el perfil
/// autenticado (`AppSession`), que sale de Supabase (o del modo demo, que NO es
/// seguridad real). Sin sesión → vuelve a la bienvenida; con otro rol → aviso
/// con salida a su propio panel. La seguridad real sigue siendo RLS en la base.
class RoleGuard extends StatefulWidget {
  const RoleGuard({super.key, required this.roles, required this.child, this.allowMfaPending = false});

  /// Solo la propia pantalla de MFA admite sesiones sin segundo factor.
  final bool allowMfaPending;
  final Set<String> roles;
  final Widget child;

  @override
  State<RoleGuard> createState() => _RoleGuardState();
}

class _RoleGuardState extends State<RoleGuard> {
  bool _redirected = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Profile?>(
      valueListenable: AppSession.profile,
      builder: (context, profile, _) {
        if (profile == null) {
          if (!_redirected) {
            _redirected = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/bienvenida', (r) => false);
            });
          }
          return const Scaffold(body: SizedBox.shrink());
        }
        if (profile.mfaPending && !widget.allowMfaPending) {
          if (!_redirected) {
            _redirected = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/mfa', (r) => false);
            });
          }
          return const Scaffold(body: SizedBox.shrink());
        }
        _redirected = false;
        if (!widget.roles.contains(profile.role)) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CheckLogo(fontSize: 32, alignment: CrossAxisAlignment.center),
                    const SizedBox(height: AppSpacing.s6),
                    const Icon(Icons.lock_outline, color: AppColors.error, size: 40),
                    const SizedBox(height: AppSpacing.s3),
                    const Text(
                      'No tienes acceso a esta sección',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.h3, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      'Tu cuenta (${profile.roleLabel}) no tiene permisos para esta pantalla.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    SizedBox(
                      width: 240,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(AppSession.entryRoute, (r) => false),
                        child: const Text('Ir a mi panel'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return widget.child;
      },
    );
  }
}
