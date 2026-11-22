import 'package:flutter/material.dart';

import '../config/demo_mode.dart';
import '../proto/data/proto_store.dart' show StaffPermission;
import '../services/app_session.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'data/mock_staff_repository.dart';
import 'data/staff_access.dart';
import 'data/staff_repository.dart';
import 'data/supabase_staff_repository.dart';
import 'screens/staff_events_screen.dart';
import 'staff_scope.dart';

/// Panel operativo del staff dentro de la web: la misma interfaz de la app
/// móvil (`lib/staff`), centrada en un ancho tipo celular para que sea
/// responsive en escritorio.
///
/// Modo real: lee `staff_accounts` (permisos y estado) y usa
/// [SupabaseStaffRepository]. Si la cuenta está desactivada se cierra la
/// sesión con un aviso. Modo demo: repositorio simulado y permisos locales.
class StaffPanel extends StatefulWidget {
  const StaffPanel({super.key});

  @override
  State<StaffPanel> createState() => _StaffPanelState();
}

class _StaffPanelState extends State<StaffPanel> {
  late final StaffRepository _repo = kDemo ? MockStaffRepository() : SupabaseStaffRepository();
  StaffAccess? _access;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadAccess();
  }

  Future<void> _loadAccess() async {
    setState(() => _failed = false);
    try {
      final access = await StaffAccess.load();
      if (!mounted) return;
      if (!access.active) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tu cuenta está desactivada. Contacta al administrador del local.')),
        );
        await AuthService.signOut();
        return;
      }
      setState(() => _access = access);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Widget _message(IconData icon, String title, String text, {VoidCallback? onRetry}) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.s4),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.h3, fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.s2),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body)),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.s4),
              OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ]),
        ),
      );

  Widget _content() {
    final access = _access;
    if (_failed) {
      return _message(Icons.wifi_off, 'No pudimos cargar tu cuenta', 'Revisa tu conexión e intenta de nuevo.', onRetry: _loadAccess);
    }
    if (access == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accentPrimary));
    }
    if (!access.can(StaffPermission.viewEvents)) {
      return _message(Icons.lock_outline, 'Sin acceso a eventos', 'Tu cuenta no tiene permiso para ver eventos. Pídeselo al administrador.');
    }
    final venue = AppSession.profile.value?.venueName ?? 'Mi local';
    return StaffScope(
      repository: _repo,
      access: access,
      child: Navigator(
        onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => StaffEventsScreen(venueName: venue)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Stack(
            children: [
              _content(),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 6,
                right: 8,
                child: IconButton(
                  tooltip: 'Cerrar sesión',
                  onPressed: AuthService.signOut,
                  icon: const Icon(Icons.logout, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
