import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Tarjeta de acceso reutilizable (bienvenida y selección de plataforma):
/// icono, título, descripción y botón, con microinteracción de hover/press.
class AccessCard extends StatefulWidget {
  const AccessCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onTap,
    this.primary = false,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onTap;

  /// Botón relleno (acción principal) o con borde.
  final bool primary;

  /// Etiqueta opcional junto al título (p. ej. "En desarrollo").
  final String? badge;

  @override
  State<AccessCard> createState() => _AccessCardState();
}

class _AccessCardState extends State<AccessCard> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.98 : (_hover ? 1.015 : 1),
          duration: const Duration(milliseconds: 140),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.all(AppSpacing.s6),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: _hover ? AppColors.accentPrimary : AppColors.bgBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s3),
                  decoration: BoxDecoration(
                    color: AppColors.accentSubtle,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(widget.icon, color: AppColors.accentPrimary, size: 28),
                ),
                const SizedBox(height: AppSpacing.s4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.s2,
                  runSpacing: AppSpacing.s1,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.inter(fontSize: AppTextSize.h3, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    if (widget.badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB800).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          widget.badge!,
                          style: GoogleFonts.inter(fontSize: AppTextSize.caption, fontWeight: FontWeight.w600, color: const Color(0xFFFFB800)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  widget.description,
                  style: GoogleFonts.inter(fontSize: AppTextSize.body, color: AppColors.textSecondary, height: 1.45),
                ),
                const SizedBox(height: AppSpacing.s6),
                widget.primary
                    ? ElevatedButton(onPressed: widget.onTap, child: Text(widget.buttonLabel))
                    : OutlinedButton(onPressed: widget.onTap, child: Text(widget.buttonLabel)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
