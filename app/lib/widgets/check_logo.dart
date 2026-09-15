import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Wordmark "CHECK.".
///
/// Dos variantes de tipografía, a propósito:
/// - `brand: false` (default) — Inter Bold, tal como está especificado en el
///   Figma del dashboard (Sidebar → Identidad). Se usa en el sidebar/UI.
/// - `brand: true` — Space Grotesk, la tipografía de marca elegida para los
///   momentos de marca (pantallas de auth, logo horizontal). Más geométrica,
///   pensada para acompañar el ícono de check_logo_icon.svg.
class CheckLogo extends StatelessWidget {
  const CheckLogo({
    super.key,
    this.fontSize = 28,
    this.subtitle,
    this.alignment = CrossAxisAlignment.start,
    this.brand = false,
  });

  final double fontSize;
  final String? subtitle;
  final CrossAxisAlignment alignment;
  final bool brand;

  @override
  Widget build(BuildContext context) {
    final wordmarkStyle = brand
        ? GoogleFonts.spaceGrotesk(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          )
        : GoogleFonts.inter(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          );

    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: TextSpan(
            style: wordmarkStyle,
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
