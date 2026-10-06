import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Progress Bar tamaño Mobile del Figma (15:79): alto 6px, pill, pista
/// `bg-input`, relleno `accent-primary`. Acepta 0–100 como pide el Figma
/// (ancho = pista × progreso / 100). En el resultado del escáner se usa
/// sobre fondo de color, por eso admite colores propios.
class StaffProgressBar extends StatelessWidget {
  const StaffProgressBar({
    super.key,
    required this.progress,
    this.trackColor = AppColors.bgInput,
    this.fillColor = AppColors.accentPrimary,
    this.height = 6,
  });

  /// 0–100.
  final double progress;
  final Color trackColor;
  final Color fillColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0, 100).toDouble();
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: trackColor)),
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: p / 100,
                child: ColoredBox(color: fillColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
