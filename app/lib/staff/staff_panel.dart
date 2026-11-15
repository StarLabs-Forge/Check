import 'package:flutter/material.dart';

import '../services/app_session.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'data/mock_staff_repository.dart';
import 'screens/staff_events_screen.dart';
import 'staff_scope.dart';

/// Panel operativo del staff dentro de la web: la misma interfaz de la app
/// móvil (`lib/staff`), centrada en un ancho tipo celular para que sea
/// responsive en escritorio. Usa `MockStaffRepository` (sin Supabase todavía).
class StaffPanel extends StatefulWidget {
  const StaffPanel({super.key});

  @override
  State<StaffPanel> createState() => _StaffPanelState();
}

class _StaffPanelState extends State<StaffPanel> {
  final _repo = MockStaffRepository();

  @override
  Widget build(BuildContext context) {
    final venue = AppSession.profile.value?.venueName ?? 'Mi local';
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Stack(
            children: [
              StaffScope(
                repository: _repo,
                child: Navigator(
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (_) => StaffEventsScreen(venueName: venue),
                  ),
                ),
              ),
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
