import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import 'staff_icon.dart';

/// Variantes del componente Button del Figma (9:71).
enum StaffButtonVariant { primary, secondary, danger, outline, ghost, disabled }

/// Button del Figma: alto 44px, radio `radius-md` (12), Inter 14 SemiBold.
/// `loading` muestra el spinner de 18px; con reduce-motion queda estático
/// (el Figma lo pide). `onPressed == null` equivale a la variante Disabled.
class StaffButton extends StatelessWidget {
  const StaffButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = StaffButtonVariant.primary,
    this.loading = false,
    this.expand = true,
    this.height = 44,
  });

  final String label;
  final VoidCallback? onPressed;
  final StaffButtonVariant variant;
  final bool loading;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final v = (onPressed == null && !loading) ? StaffButtonVariant.disabled : variant;
    final (bg, fg, border) = switch (v) {
      StaffButtonVariant.primary => (AppColors.accentPrimary, AppColors.bgPrimary, null),
      StaffButtonVariant.secondary => (AppColors.bgInput, AppColors.textPrimary, AppColors.bgBorder),
      StaffButtonVariant.danger => (AppColors.error, AppColors.textPrimary, null),
      StaffButtonVariant.outline => (null, AppColors.accentPrimary, AppColors.accentPrimary),
      StaffButtonVariant.ghost => (null, AppColors.textSecondary, null),
      StaffButtonVariant.disabled => (AppColors.bgInput, AppColors.textDisabled, AppColors.bgInput),
    };

    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: reduceMotion
                ? StaffIcon(StaffIcons.spinner, size: 18, color: fg)
                : CircularProgressIndicator(strokeWidth: 2, color: fg),
          ),
          const SizedBox(width: AppSpacing.s2),
        ],
        Text(
          label,
          style: GoogleFonts.inter(fontSize: AppTextSize.body, fontWeight: FontWeight.w600, color: fg),
        ),
      ],
    );

    final button = Material(
      color: bg ?? Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: border == null ? BorderSide.none : BorderSide(color: border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: loading ? null : onPressed,
        child: SizedBox(height: height, child: Center(child: content)),
      ),
    );

    return Semantics(
      button: true,
      enabled: onPressed != null && !loading,
      label: label,
      excludeSemantics: true,
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}
