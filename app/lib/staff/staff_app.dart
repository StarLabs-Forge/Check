import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'data/mock_staff_repository.dart';
import 'data/staff_repository.dart';
import 'screens/staff_events_screen.dart';
import 'staff_scope.dart';

/// Raíz de la app móvil Staff. Se arranca con `lib/main_staff.dart`.
class StaffApp extends StatelessWidget {
  StaffApp({super.key, StaffRepository? repository}) : repository = repository ?? MockStaffRepository();

  final StaffRepository repository;

  @override
  Widget build(BuildContext context) {
    return StaffScope(
      repository: repository,
      child: MaterialApp(
        title: 'CHECK Staff',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        // Primera pantalla del Figma "📱 App Móvil": Eventos activos.
        home: const StaffEventsScreen(),
      ),
    );
  }
}
