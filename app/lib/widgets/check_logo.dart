import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Wordmark "CHECK." tal como aparece en el Figma (Sidebar → Identidad):
/// texto blanco + punto final en verde acento. Deliberadamente sin logotipo
/// aparte — así estas pantallas no dependen de un asset todavía sin definir.
class CheckLogo extends StatelessWidget {
  const CheckLogo({
    super.key,
    this.fontSize = 28,
    this.subtitle,
    this.alignment = CrossAxisAlignment.start,
  });

  final double fontSize;
  final String? subtitle;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
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
