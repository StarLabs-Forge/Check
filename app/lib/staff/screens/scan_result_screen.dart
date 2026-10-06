import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../data/staff_models.dart';
import '../staff_scope.dart';
import '../theme/staff_tokens.dart';
import '../widgets/staff_icon.dart';
import '../widgets/staff_progress_bar.dart';

/// "Scanner Result Screen" del Figma (19:104) — 390×844, resultado a pantalla
/// completa. Color + ícono + texto redundantes (puerta con poca luz).
/// Retorno automático a los 2.5 s; el botón inferior vuelve de inmediato.
class ScanResultScreen extends StatefulWidget {
  const ScanResultScreen({super.key, required this.outcome});

  final ScanOutcome outcome;

  /// Ruta sin transición lenta: el resultado debe aparecer al instante.
  static Route<void> route(ScanOutcome outcome) => PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 120),
        reverseTransitionDuration: const Duration(milliseconds: 120),
        pageBuilder: (context, animation, secondaryAnimation) => ScanResultScreen(outcome: outcome),
        transitionsBuilder: (context, anim, secondaryAnimation, child) => FadeTransition(opacity: anim, child: child),
      );

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  Timer? _auto;

  @override
  void initState() {
    super.initState();
    widget.outcome.kind == ScanResultKind.success ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
    _auto = Timer(const Duration(milliseconds: 2500), _close);
  }

  @override
  void dispose() {
    _auto?.cancel();
    super.dispose();
  }

  void _close() {
    _auto?.cancel();
    if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.outcome;
    final mq = MediaQuery.of(context);

    final _Look look = switch (o.kind) {
      ScanResultKind.success => const _Look(
          bg: StaffColors.scannerSuccessBg,
          icon: StaffIcons.check,
          iconColor: AppColors.success,
          title: 'ACCESO PERMITIDO',
          pill: Color(0x2EFFFFFF), // text-primary @ 18 %
          actionBg: AppColors.textPrimary,
          actionFg: AppColors.success,
          actionLabel: 'Siguiente Scan',
        ),
      ScanResultKind.alreadyRegistered => const _Look(
          bg: StaffColors.scannerWarningBg,
          icon: StaffIcons.warning,
          iconColor: StaffColors.warning,
          title: 'YA REGISTRADO',
          pill: Color(0x38000000), // black @ 22 %
          actionBg: StaffColors.black,
          actionFg: AppColors.textPrimary,
          actionLabel: 'Cerrar',
        ),
      ScanResultKind.denied => const _Look(
          bg: StaffColors.scannerErrorBg,
          icon: StaffIcons.x,
          iconColor: AppColors.error,
          title: 'ACCESO DENEGADO',
          pill: Color(0x38000000),
          actionBg: AppColors.textPrimary,
          actionFg: AppColors.error,
          actionLabel: 'Volver a intentar',
        ),
    };

    final detail = switch (o.kind) {
      ScanResultKind.success => 'Ticket válido · ${hhmm(o.checkedInAt!)}',
      ScanResultKind.alreadyRegistered => 'Ingresó a las ${hhmm(o.checkedInAt!)}',
      ScanResultKind.denied => 'Ticket no encontrado o inválido',
    };

    final white = GoogleFonts.inter(color: AppColors.textPrimary, height: 1.4);

    return Scaffold(
      backgroundColor: look.bg,
      body: Padding(
        padding: EdgeInsets.fromLTRB(24, mq.size.height * 176 / 844, 24, math.max(44, mq.padding.bottom + 16)),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Semantics(
                  liveRegion: true,
                  label: '${look.title}. ${o.guestName ?? ''}. $detail',
                  excludeSemantics: true,
                  child: Column(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: const BoxDecoration(color: AppColors.textPrimary, shape: BoxShape.circle),
                        child: Center(child: StaffIcon(look.icon, size: 64, color: look.iconColor)),
                      ),
                      const SizedBox(height: AppSpacing.s6),
                      Text(
                        look.title,
                        textAlign: TextAlign.center,
                        style: white.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                      if (o.guestName != null) ...[
                        const SizedBox(height: AppSpacing.s6),
                        Text(
                          o.guestName!,
                          textAlign: TextAlign.center,
                          style: white.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.s6),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.s3),
                        decoration: BoxDecoration(color: look.pill, borderRadius: BorderRadius.circular(AppRadius.full)),
                        child: Text(
                          detail,
                          textAlign: TextAlign.center,
                          style: white.copyWith(fontSize: AppTextSize.body, fontWeight: FontWeight.w500),
                        ),
                      ),
                      if (o.kind == ScanResultKind.success && o.capacity != null) ...[
                        const SizedBox(height: AppSpacing.s6),
                        SizedBox(
                          width: 310, // ancho de la barra en el Figma (342 − 2×16)
                          child: StaffProgressBar(
                            progress: o.capacity == 0 ? 0 : o.checkins! / o.capacity! * 100,
                            trackColor: const Color(0x40FFFFFF), // text-primary @ 25 %
                            fillColor: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s6),
                        Text(
                          '${o.checkins} / ${o.capacity} ingresados',
                          style: white.copyWith(fontSize: AppTextSize.body),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Semantics(
              button: true,
              label: look.actionLabel,
              excludeSemantics: true,
              child: Material(
                color: look.actionBg,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: _close,
                  child: SizedBox(
                    height: 52,
                    width: double.infinity,
                    child: Center(
                      child: Text(
                        look.actionLabel,
                        style: GoogleFonts.inter(
                          fontSize: AppTextSize.body,
                          fontWeight: FontWeight.w600,
                          color: look.actionFg,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Look {
  const _Look({
    required this.bg,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.pill,
    required this.actionBg,
    required this.actionFg,
    required this.actionLabel,
  });

  final Color bg;
  final StaffIcons icon;
  final Color iconColor;
  final String title;
  final Color pill;
  final Color actionBg;
  final Color actionFg;
  final String actionLabel;
}
