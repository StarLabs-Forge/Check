import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../data/staff_models.dart';
import '../staff_scope.dart';
import '../theme/staff_tokens.dart';
import '../widgets/staff_icon.dart';
import 'scan_result_screen.dart';

/// Figma → 📱 App Móvil → "Scanner activo" (31:5) y "Sin conexión" (32:62).
///
/// La cámara real requiere un plugin nativo (p. ej. `mobile_scanner`), que aún
/// no está en el pubspec: el visor se dibuja como en el Figma y en modo debug
/// una franja "DEMO" dispara escaneos simulados. La integración de la cámara
/// solo debe llamar a [_onToken] con el texto leído del QR.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key, required this.event});

  final StaffEvent event;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  late StaffEvent _event = widget.event;
  bool _torch = false;
  bool _busy = false;
  bool _offline = false;
  bool _retrying = false;

  Future<void> _onToken(String token) async {
    if (_busy || _offline) return;
    setState(() => _busy = true);
    try {
      final outcome = await StaffScope.of(context).scanQr(eventId: _event.id, token: token);
      if (!mounted) return;
      if (outcome.kind == ScanResultKind.success) {
        _event = _event.copyWith(checkins: outcome.checkins);
      }
      await Navigator.of(context).push(ScanResultScreen.route(outcome));
    } catch (_) {
      // Sin red / backend caído: la validación es en línea, no hay modo offline.
      if (mounted) setState(() => _offline = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    final online = await StaffScope.of(context).isOnline();
    if (!mounted) return;
    setState(() {
      _retrying = false;
      if (online) _offline = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: StaffColors.black,
      body: Stack(
        children: [
          // ── Escáner (31:5) ─────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s2),
              child: Column(
                children: [
                  const SizedBox(height: 44), // reserva de la cabecera (se dibuja arriba)
                  const SizedBox(height: AppSpacing.s4),
                  Expanded(child: _Viewfinder(onDemoToken: kDebugMode ? _onToken : null, busy: _busy)),
                  const SizedBox(height: 46),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            liveRegion: true,
                            child: Container(
                              height: 52,
                              padding: const EdgeInsets.all(AppSpacing.s4),
                              decoration: BoxDecoration(
                                color: AppColors.bgInput,
                                borderRadius: BorderRadius.circular(AppRadius.full),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.accentPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.s2),
                                  Text(
                                    '${_event.checkins} / ${_event.capacity} ingresados',
                                    style: GoogleFonts.inter(
                                      fontSize: AppTextSize.body,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s5),
                        Semantics(
                          button: true,
                          toggled: _torch,
                          label: 'Linterna',
                          excludeSemantics: true,
                          child: Material(
                            color: AppColors.bgInput,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => setState(() => _torch = !_torch),
                              child: SizedBox(
                                width: 56,
                                height: 56,
                                child: Center(
                                  child: StaffIcon(
                                    _torch ? StaffIcons.flashlight : StaffIcons.flashlightOff,
                                    color: _torch ? AppColors.accentPrimary : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: mq.padding.bottom > 0 ? AppSpacing.s8 : 56),
                ],
              ),
            ),
          ),

          // ── Sin conexión (32:62): overlay negro al 86 % ────────────────
          if (_offline)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {}, // absorbe toques: no se puede escanear sin red
                child: ColoredBox(color: StaffColors.black.withValues(alpha: 0.86)),
              ),
            ),
          if (_offline)
            Positioned(
              left: AppSpacing.s6,
              right: AppSpacing.s6,
              top: mq.size.height * 250 / 844,
              child: Semantics(
                liveRegion: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const StaffIcon(StaffIcons.wifiOff, size: 64, color: AppColors.textPrimary),
                    const SizedBox(height: AppSpacing.s6),
                    Text(
                      'Sin conexión a internet',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: AppTextSize.h2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    Text(
                      'El scanner necesita conexión para validar tickets',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: AppTextSize.bodyLg,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    // Botón "Reintentar conexión": outline blanco, 52px.
                    Semantics(
                      button: true,
                      label: 'Reintentar',
                      excludeSemantics: true,
                      child: Material(
                        color: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          side: const BorderSide(color: AppColors.textPrimary),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          onTap: _retry,
                          child: SizedBox(
                            height: 52,
                            width: double.infinity,
                            child: Center(
                              child: _retrying
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary),
                                    )
                                  : Text(
                                      'Reintentar',
                                      style: GoogleFonts.inter(
                                        fontSize: AppTextSize.body,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
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
            ),

          // ── Cabecera del scanner: encima del overlay (en el Figma queda
          //    atenuada al 14 % cuando no hay conexión) y siempre tocable. ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s2, left: AppSpacing.s6, right: AppSpacing.s6),
              child: Opacity(
                opacity: _offline ? 0.14 : 1,
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: IconButton(
                        padding: const EdgeInsets.all(10),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Cerrar scanner',
                        icon: const StaffIcon(StaffIcons.x, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s3),
                    Expanded(
                      child: Text(
                        'ESCANEANDO · ${_event.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: AppTextSize.caption,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Visor de cámara" (520px, `bg-primary`): esquinas de 278px, línea de
/// escaneo de 2px y guía en pastilla. Todo centrado horizontalmente.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder({required this.onDemoToken, required this.busy});

  final Future<void> Function(String token)? onDemoToken;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.bgPrimary,
      child: LayoutBuilder(
        builder: (context, c) {
          // El Figma usa 520px de alto; en pantallas bajas se comprime el margen superior.
          final top = (c.maxHeight - 520).clamp(-70.0, 0.0) + 70;
          return Stack(
            children: [
              Positioned(
                top: top,
                left: 0,
                right: 0,
                child: Center(
                  child: Semantics(
                    label: 'Visor de cámara',
                    child: SizedBox(
                      width: 278,
                      height: 278,
                      child: CustomPaint(painter: const _CornersPainter()),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: top + 120, // 190 − 70 en el Figma
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 252,
                    height: 2,
                    decoration: BoxDecoration(
                      color: AppColors.accentPrimary,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 68,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.s3),
                    decoration: BoxDecoration(
                      color: AppColors.bgInput,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      busy ? 'Validando…' : 'Apunta al código QR del ticket',
                      style: GoogleFonts.inter(fontSize: AppTextSize.body, color: AppColors.textPrimary, height: 1.4),
                    ),
                  ),
                ),
              ),
              if (onDemoToken != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _DemoStrip(onToken: onDemoToken!, enabled: !busy),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Solo en debug: sustituye a la cámara hasta integrar el plugin.
class _DemoStrip extends StatelessWidget {
  const _DemoStrip({required this.onToken, required this.enabled});

  final Future<void> Function(String token) onToken;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, String token) => TextButton(
          onPressed: enabled ? () => onToken(token) : null,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            foregroundColor: StaffColors.muted,
          ),
          child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500)),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('DEMO', style: GoogleFonts.inter(fontSize: 11, color: StaffColors.muted, letterSpacing: 0.6)),
        chip('Válido', 'VALID'),
        chip('Ya usado', 'USED'),
        chip('Inválido', 'NOPE'),
        chip('Sin red', 'OFFLINE'),
      ],
    );
  }
}

/// "Esquinas QR" (31:13): vector de 278px, trazo 4px `accent-primary`,
/// brazos de ~54px y radio ~20px, inset de 2px.
class _CornersPainter extends CustomPainter {
  const _CornersPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accentPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const inset = 2.0;
    const len = 54.0;
    const r = 20.0;
    final l = inset, t = inset, rt = size.width - inset, b = size.height - inset;

    canvas.drawPath(
      Path()
        ..moveTo(l, t + len)
        ..lineTo(l, t + r)
        ..quadraticBezierTo(l, t, l + r, t)
        ..lineTo(l + len, t),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(rt - len, t)
        ..lineTo(rt - r, t)
        ..quadraticBezierTo(rt, t, rt, t + r)
        ..lineTo(rt, t + len),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(l, b - len)
        ..lineTo(l, b - r)
        ..quadraticBezierTo(l, b, l + r, b)
        ..lineTo(l + len, b),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(rt - len, b)
        ..lineTo(rt - r, b)
        ..quadraticBezierTo(rt, b, rt, b - r)
        ..lineTo(rt, b - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CornersPainter old) => false;
}
