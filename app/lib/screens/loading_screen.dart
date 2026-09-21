import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/check_logo.dart';

/// Pantalla de carga / splash — implementa el frame "Splash — Cargando"
/// del Figma (🔐 Auth Flow): logo CHECK grande centrado, subtítulo
/// "Dharma Club", spinner y texto "Cargando...".
///
/// Se usa como arranque de la app (`main.dart` navega a Login después de
/// un delay simulado) y queda disponible como widget reusable para
/// cualquier otro momento de carga real una vez haya backend.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CheckLogo(fontSize: 64, subtitle: 'Dharma Club'),
            const SizedBox(height: AppSpacing.s8),
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation(AppColors.accentPrimary),
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            const Text(
              'Cargando...',
              style: TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
            ),
          ],
        ),
      ),
    );
  }
}
