import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_scaffold.dart';

/// Estado vacío reusable — implementa el frame "Estado — Próximamente" del
/// Figma (🖥️ Dashboard Web): ícono en círculo, título, descripción y botón
/// "Volver al Dashboard".
///
/// Sirve para dos casos:
/// 1. Secciones del panel Admin que todavía no tienen diseño/funcionalidad
///    (ej. Configuración) — se pasa `current` y se muestra dentro del
///    `AdminScaffold`, con la sidebar y el nav item correspondiente activo.
/// 2. Rutas que no existen (404) — sin `current`, se muestra standalone a
///    pantalla completa (usado en `onUnknownRoute` de `main.dart`).
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({
    super.key,
    this.current,
    this.title = 'Esta sección estará disponible pronto',
    this.message = 'Estamos trabajando en este módulo del panel Admin. Vuelve pronto.',
    this.icon = '🚧',
  });

  /// Si se provee, la pantalla se muestra dentro del AdminScaffold (sidebar +
  /// nav activo en esa ruta). Si es null, se muestra standalone — pensado
  /// para 404 / rutas desconocidas donde no aplica una sidebar de Admin.
  final AdminRoute? current;
  final String title;
  final String message;
  final String icon;

  Widget _content(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentSubtle,
                border: Border.all(color: AppColors.accentPrimary, width: 1.5),
              ),
              child: Text(icon, style: const TextStyle(fontSize: 40)),
            ),
            const SizedBox(height: AppSpacing.s5),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.h2, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.s3),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
              ),
            ),
            const SizedBox(height: AppSpacing.s5),
            SizedBox(
              width: 220,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.bgBorder),
                ),
                child: const Text('Volver al Dashboard'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (current != null) {
      return AdminScaffold(current: current!, body: _content(context));
    }
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(child: _content(context)),
    );
  }
}
