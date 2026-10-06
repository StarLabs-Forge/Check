import 'package:flutter/material.dart';

/// Tokens del Figma (Foundations → 01 · Paleta de color) que `AppTheme` aún no
/// expone y que usa la app móvil de Staff. Valores copiados 1:1 del Figma;
/// los tokens que ya existen (bgPrimary, accentPrimary, error…) se reutilizan
/// desde `lib/theme/app_theme.dart`, no se duplican acá.
class StaffColors {
  StaffColors._();

  static const Color black = Color(0xFF000000);
  static const Color warning = Color(0xFFFFB800);
  static const Color muted = Color(0xFF555555);
  static const Color bgAuth = Color(0xFF0F0F0F);

  // Fondos a pantalla completa del resultado del escáner.
  static const Color scannerSuccessBg = Color(0xFF00C853);
  static const Color scannerWarningBg = Color(0xFFFFB800);
  static const Color scannerErrorBg = Color(0xFFFF3B3B);
}

/// Efecto "CHECK/Focus Glow" del Figma (drop shadow #00FF88 @ 18 %, blur 12).
const List<BoxShadow> staffFocusGlow = [
  BoxShadow(color: Color(0x2E00FF88), blurRadius: 12),
];
