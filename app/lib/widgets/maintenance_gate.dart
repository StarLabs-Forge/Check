import 'package:flutter/material.dart';

import '../services/app_session.dart';
import '../services/superadmin_service.dart' show PlatformStatus;
import '../theme/app_theme.dart';

/// Cubre la app con un aviso mientras la plataforma está en mantenimiento.
///
/// El superadministrador (sesión iniciada) ve la app normal; los demás pueden
/// abrir el acceso de administradores para iniciar sesión. Es una barrera de
/// interfaz: el inicio de sesión de cualquier otro rol se revierte en
/// `main.dart`, pero las RPC públicas (compra) no se bloquean en la base.
class MaintenanceGate extends StatefulWidget {
  const MaintenanceGate({super.key, required this.navigatorKey, required this.child});
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<MaintenanceGate> createState() => _MaintenanceGateState();
}

class _MaintenanceGateState extends State<MaintenanceGate> {
  bool _showLogin = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([PlatformStatus.instance, AppSession.profile]),
      builder: (context, _) {
        final status = PlatformStatus.instance;
        final isSuper = AppSession.profile.value?.role == 'super_admin';
        final signedIn = AppSession.profile.value != null;
        final blocked = status.maintenance && !isSuper && (!_showLogin || signedIn);
        // El Navigator siempre queda montado en la misma posición para no perder la pila de pantallas.
        return Stack(children: [Positioned.fill(child: widget.child), if (blocked) Positioned.fill(child: _notice(status))]);
      },
    );
  }

  Widget _notice(PlatformStatus status) {
        return Material(
          color: AppColors.bgPrimary,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s6),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.construction, size: 56, color: AppColors.accentPrimary),
                  const SizedBox(height: AppSpacing.s4),
                  const Text('Estamos en mantenimiento',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.h2, fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppSpacing.s3),
                  Text(
                    status.message.isEmpty ? 'Volvemos en unos minutos.' : status.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
                  ),
                  const SizedBox(height: AppSpacing.s6),
                  TextButton(
                    onPressed: () {
                      setState(() => _showLogin = true);
                      WidgetsBinding.instance.addPostFrameCallback((_) => widget.navigatorKey.currentState?.pushNamed('/login'));
                    },
                    child: const Text('Acceso del equipo CHECK'),
                  ),
                ]),
              ),
            ),
          ),
        );
  }
}
