import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import 'motion.dart';

/// Layout compartido por Login / Registro / Verificación.
///
/// * Pantallas anchas (≥ 900 px): panel de marca a la izquierda (logo,
///   mensaje y tres beneficios) y formulario a la derecha, en una sola
///   tarjeta. Aprovecha el espacio en lugar de dejar un formulario angosto
///   flotando en el vacío.
/// * Celulares y ventanas angostas: logo con ícono arriba y tarjeta de
///   formulario debajo.
///
/// Todo debe verse de un vistazo: el contenido se compacta según el alto
/// disponible y solo hace scroll como último recurso (p. ej. con el teclado
/// abierto).
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.maxWidth = 420,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final double maxWidth;

  /// Alto bajo el cual la pantalla pasa a modo compacto.
  static const double compactHeight = 780;

  /// Ancho desde el cual se muestra el panel de marca lateral.
  static const double splitWidth = 900;

  /// ¿Está el formulario en modo compacto? Los hijos lo consultan para
  /// reducir separaciones u ocultar elementos secundarios.
  static bool isCompact(BuildContext context) => _AuthDensity.of(context);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final compact = c.maxHeight < compactHeight;
            final split = c.maxWidth >= splitWidth;
            final pad = compact ? AppSpacing.s4 : AppSpacing.s6;

            final form = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: AppTextSize.h2, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: AppTextSize.body, color: AppColors.textSecondary),
                ),
                SizedBox(height: compact ? AppSpacing.s4 : AppSpacing.s5),
                child,
              ],
            );

            final Widget content;
            if (split) {
              content = Reveal(
                dy: 18,
                child: Container(
                  constraints: BoxConstraints(maxWidth: maxWidth + 440),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(AppRadius.modal),
                    border: Border.all(color: AppColors.bgBorder),
                    boxShadow: [BoxShadow(color: AppColors.accentPrimary.withValues(alpha: 0.06), blurRadius: 60, offset: const Offset(0, 20))],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: compact ? 470 : 500),
                    child: Stack(
                      children: [
                        // El formulario define la altura; el panel de marca la rellena.
                        const Positioned.fill(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(widthFactor: 5 / 11, heightFactor: 1, child: _BrandPanel()),
                          ),
                        ),
                        Row(
                          children: [
                            const Expanded(flex: 5, child: SizedBox.shrink()),
                            Expanded(
                              flex: 6,
                              child: Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: compact ? AppSpacing.s5 : AppSpacing.s8),
                                  child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: form),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            } else {
              content = ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Reveal(dy: -8, scale: 0.96, child: BrandMark(iconSize: compact ? 34 : 42, fontSize: compact ? 26 : 32)),
                    SizedBox(height: compact ? AppSpacing.s3 : AppSpacing.s5),
                    Reveal(
                      delay: const Duration(milliseconds: 90),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(pad),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.bgBorder),
                        ),
                        child: form,
                      ),
                    ),
                  ],
                ),
              );
            }

            return _AuthDensity(
              compact: compact,
              child: Stack(
                children: [
                  // Resplandor verde sutil detrás del formulario.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(0, -0.9),
                            radius: 1.1,
                            colors: [AppColors.accentPrimary.withValues(alpha: 0.07), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: compact ? AppSpacing.s3 : AppSpacing.s4),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight - (compact ? AppSpacing.s6 : AppSpacing.s8)),
                      child: Center(child: content),
                    ),
                  ),
                  if (Navigator.of(context).canPop())
                    Positioned(
                      top: AppSpacing.s1,
                      left: AppSpacing.s2,
                      child: IconButton(
                        tooltip: 'Volver',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back, color: AppColors.textSecondary),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Logo de CHECK: ícono de marca + wordmark en una sola fila.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.iconSize = 40, this.fontSize = 30});

  final double iconSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset('assets/branding/check_logo_icon.svg', width: iconSize, height: iconSize),
        SizedBox(width: fontSize * 0.3),
        RichText(
          text: TextSpan(
            style: GoogleFonts.inter(fontSize: fontSize, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            children: const [
              TextSpan(text: 'CHECK'),
              TextSpan(text: '.', style: TextStyle(color: AppColors.accentPrimary)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Panel lateral de marca (solo pantallas anchas).
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.qr_code_2_rounded, 'Acceso con QR', 'Cada entrada es única y se valida en la puerta.'),
      (Icons.verified_outlined, 'Pagos verificados', 'El local confirma el depósito antes de habilitar entradas.'),
      (Icons.bolt_rounded, 'Todo en tiempo real', 'Ingresos, ocupación y actividad al instante.'),
    ];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0F2E1E), Color(0xFF0C1A13), AppColors.bgSurface]),
        border: Border(right: BorderSide(color: AppColors.bgBorder)),
      ),
      child: Stack(
        children: [
          // Aros decorativos.
          const Positioned(right: -70, bottom: -70, child: _Ring(220, 0.10)),
          const Positioned(right: -30, bottom: -30, child: _Ring(140, 0.12)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Reveal(dx: -12, dy: 0, child: BrandMark(iconSize: 48, fontSize: 36)),
              const SizedBox(height: AppSpacing.s5),
              Reveal(
                delay: const Duration(milliseconds: 100),
                child: Text(
                  'Tu puerta,\nbajo control.',
                  style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, height: 1.15, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: AppSpacing.s6),
              for (final (i, it) in items.indexed)
                Reveal(
                  delay: Duration(milliseconds: 200 + i * 80),
                  dx: -10,
                  dy: 0,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.s2),
                          decoration: BoxDecoration(color: AppColors.accentPrimary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.sm)),
                          child: Icon(it.$1, size: 20, color: AppColors.accentPrimary),
                        ),
                        const SizedBox(width: AppSpacing.s3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(it.$2, style: GoogleFonts.inter(fontSize: AppTextSize.body, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                              const SizedBox(height: 2),
                              Text(it.$3, style: GoogleFonts.inter(fontSize: AppTextSize.caption, height: 1.4, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring(this.size, this.alpha);

  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.accentPrimary.withValues(alpha: alpha), width: 1.5)),
      );
}

class _AuthDensity extends InheritedWidget {
  const _AuthDensity({required this.compact, required super.child});

  final bool compact;

  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_AuthDensity>()?.compact ?? false;

  @override
  bool updateShouldNotify(_AuthDensity old) => old.compact != compact;
}

/// Separación vertical que se reduce a dos tercios en modo compacto.
class AuthGap extends StatelessWidget {
  const AuthGap([this.height = AppSpacing.s3, Key? key]) : super(key: key);

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(height: AuthScaffold.isCompact(context) ? height * 0.66 : height);
}

/// Muestra un mensaje de error de formulario con una entrada suave: el
/// resto del formulario baja en lugar de «saltar».
class AuthError extends StatelessWidget {
  const AuthError(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: Motion.base,
      curve: Motion.enter,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: Motion.base,
        child: message == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                key: ValueKey(message),
                padding: const EdgeInsets.only(top: AppSpacing.s2),
                child: Text(
                  message!,
                  style: const TextStyle(color: AppColors.error, fontSize: AppTextSize.caption),
                ),
              ),
      ),
    );
  }
}

/// Dos campos lado a lado cuando hay ancho; apilados en pantallas angostas.
class FieldPair extends StatelessWidget {
  const FieldPair({super.key, required this.a, required this.b, this.gap = AppSpacing.s3, this.stacked = false});

  final Widget a;
  final Widget b;
  final double gap;

  /// Fuerza un campo debajo del otro aunque haya ancho.
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (!stacked && c.maxWidth >= 400) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: a), SizedBox(width: gap), Expanded(child: b)],
          );
        }
        return Column(children: [a, SizedBox(height: gap), b]);
      },
    );
  }
}

/// Botón "Continuar con Google" — solo UI, sin integración real todavía.
/// El ícono se arma con formas nativas (sin asset) para no depender de un
/// paquete de íconos de terceros en esta etapa de solo-frontend.
class GoogleButton extends StatelessWidget {
  const GoogleButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      enabled: onPressed != null,
      child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.bgBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: const Text(
              'G',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF4285F4),
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Text(label),
        ],
      ),
      ),
    );
  }
}

/// Separador "o continúa con" reutilizado en Login/Registro.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key, this.label = 'o continúa con'});

  final String label;

  @override
  Widget build(BuildContext context) {
    if (AuthScaffold.isCompact(context)) return const SizedBox.shrink();
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.bgBorder)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppTextSize.caption,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.bgBorder)),
      ],
    );
  }
}

/// Botón principal de los formularios de auth: se encoge al pulsar y cambia
/// el texto por un spinner mientras se envía (sin cambiar de tamaño).
class AuthSubmit extends StatelessWidget {
  const AuthSubmit({super.key, required this.label, required this.loading, required this.onPressed});

  final String label;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      enabled: !loading,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        child: AnimatedSwitcher(
          duration: Motion.fast,
          transitionBuilder: (child, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: a, child: child)),
          child: loading
              ? const SizedBox(
                  key: ValueKey('spinner'),
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.bgPrimary),
                )
              : Text(label, key: const ValueKey('label')),
        ),
      ),
    );
  }
}
