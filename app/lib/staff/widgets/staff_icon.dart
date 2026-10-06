import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Familia de iconos de la app Staff (Figma → 🧩 Components → 00 · Iconos:
/// retícula 24px, trazo 2px, contornos redondeados).
enum StaffIcons {
  check('assets/icons/check.svg'), // Icono/Check
  warning('assets/icons/warning.svg'), // Icono/Warning
  x('assets/icons/x.svg'), // Icono/X
  flashlight('assets/icons/flashlight.svg'), // Icono/Flashlight
  flashlightOff(Icons.flashlight_off_outlined),
  wifiOff('assets/icons/wifioff.svg'), // Icono/WifiOff
  spinner(Icons.sync_rounded); // Icono/Spinner

  const StaffIcons(this.data);
  final dynamic data;
}

class StaffIcon extends StatelessWidget {
  const StaffIcon(this.icon, {super.key, this.size = 24, this.color, this.semanticLabel});

  final StaffIcons icon;
  final double size;
  final Color? color;

  /// Los iconos del Figma piden "acompañar con etiqueta accesible".
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final data = icon.data;

    if (data is String) {
      return SvgPicture.asset(
        data,
        width: size,
        height: size,
        colorFilter: color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null,
        semanticsLabel: semanticLabel,
      );
    }

    return Icon(data as IconData, size: size, color: color, semanticLabel: semanticLabel);
  }
}
