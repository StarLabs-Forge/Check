import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Wordmark "CHECK." — Inter Bold en todos los tamaños, tal como lo define
/// el Figma en Foundations → 02 · Tipografía (token `size-display`: 48px /
/// Bold / Inter, con esa misma muestra "CHECK." como ejemplo del token) y en
/// 05 · Logotipo, donde las 3 versiones de marca (On Dark/Light/Surface)
/// usan el mismo componente "Logo CHECK" en Inter.
///
/// `fontSize` cambia el tamaño según el contexto: 28px para el uso chico del
/// sidebar (como en el Dashboard Principal) y 48px para el uso grande
/// (`size-display`, pantallas de auth).
///
/// `showIcon` agrega el ícono de marca (assets/branding/check_logo_icon.svg)
/// arriba del wordmark. El Figma del sidebar NO incluye ícono — solo texto —
/// así que el sidebar se queda con `showIcon: false` (default) para no
/// desviarse del diseño ya aprobado; los "momentos de marca" sin spec en
/// Figma (pantallas de auth) sí lo usan.
class CheckLogo extends StatelessWidget {
  const CheckLogo({
    super.key,
    this.fontSize = 28,
    this.subtitle,
    this.alignment = CrossAxisAlignment.start,
    this.showIcon = false,
  });

  final double fontSize;
  final String? subtitle;
  final CrossAxisAlignment alignment;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showIcon) ...[
          SvgPicture.asset(
            'assets/branding/check_logo_icon.svg',
            width: fontSize * 1.5,
            height: fontSize * 1.5,
          ),
          const SizedBox(height: AppSpacing.s3),
        ],
        RichText(
          text: TextSpan(
            style: GoogleFonts.inter(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            children: [
              const TextSpan(text: 'CHECK'),
              TextSpan(
                text: '.',
                style: TextStyle(color: AppColors.accentPrimary),
              ),
            ],
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.s2),
          Text(
            subtitle!,
            style: GoogleFonts.inter(
              fontSize: AppTextSize.caption,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
