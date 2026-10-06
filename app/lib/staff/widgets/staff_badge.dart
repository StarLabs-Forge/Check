import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';

/// Badge del Figma (11:44): pill de 30px, borde 1px, Inter 12 Medium.
/// Para tickets: Ingresó / Pendiente. Para eventos: Activo / Borrador.
enum StaffBadgeStatus { activo, borrador, cerrado, ingreso, pendiente, cancelado }

class StaffBadge extends StatelessWidget {
  const StaffBadge(this.status, {super.key});

  final StaffBadgeStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, border, fg) = switch (status) {
      StaffBadgeStatus.activo => ('Activo', AppColors.accentSubtle, AppColors.accentPrimary, AppColors.accentPrimary),
      StaffBadgeStatus.ingreso => ('Ingresó', AppColors.accentSubtle, AppColors.accentPrimary, AppColors.accentPrimary),
      StaffBadgeStatus.borrador => ('Borrador', AppColors.bgDraft, AppColors.textDisabled, AppColors.textSecondary),
      StaffBadgeStatus.pendiente => ('Pendiente', AppColors.bgDraft, AppColors.textDisabled, AppColors.textSecondary),
      StaffBadgeStatus.cerrado => ('Cerrado', AppColors.bgDanger, AppColors.error, AppColors.error),
      StaffBadgeStatus.cancelado => ('Cancelado', AppColors.bgDanger, AppColors.error, AppColors.error),
    };

    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: AppTextSize.caption, fontWeight: FontWeight.w500, color: fg),
      ),
    );
  }
}
