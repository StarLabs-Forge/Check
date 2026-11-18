import 'package:flutter/material.dart';

/// Sistema de movimiento de CHECK.
///
/// Principios: el movimiento guía la vista (qué apareció, qué se pulsó, qué
/// cambió), nunca decora. Todo dura entre 140 y 450 ms, entra con
/// desaceleración y respeta «reducir animaciones» del sistema.
class Motion {
  Motion._();

  static const Duration fast = Duration(milliseconds: 140);
  static const Duration base = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 420);

  /// Entradas: arranca rápido y se asienta suave.
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;

  /// Pequeño «rebote» para confirmaciones (pago aprobado, check).
  static const Curve pop = Curves.easeOutBack;

  /// Respeta la preferencia de accesibilidad del sistema.
  static bool reduced(BuildContext context) => MediaQuery.disableAnimationsOf(context);
}

/// Aparición con fundido + leve desplazamiento (y escala opcional).
/// Se reproduce una sola vez al montarse; con [delay] permite escalonar
/// listas y bloques sin usar temporizadores.
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.dy = 14,
    this.dx = 0,
    this.scale = 1,
    this.duration = Motion.slow,
    this.curve = Motion.enter,
  });

  final Widget child;
  final Duration delay;
  final double dy;
  final double dx;

  /// Escala inicial (1 = sin escala).
  final double scale;
  final Duration duration;
  final Curve curve;

  /// Retardo escalonado para el elemento [index] de una lista (máx. 8 pasos).
  static Duration stagger(int index, {int stepMs = 55}) => Duration(milliseconds: (index > 8 ? 8 : index) * stepMs);

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    final total = widget.delay + widget.duration;
    _c = AnimationController(vsync: this, duration: total);
    final start = total.inMilliseconds == 0 ? 0.0 : widget.delay.inMilliseconds / total.inMilliseconds;
    _t = CurvedAnimation(parent: _c, curve: Interval(start, 1, curve: widget.curve));
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return widget.child;
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) {
        final v = _t.value;
        Widget w = Opacity(opacity: v.clamp(0.0, 1.0), child: child);
        if (widget.dx != 0 || widget.dy != 0) {
          w = Transform.translate(offset: Offset((1 - v) * widget.dx, (1 - v) * widget.dy), child: w);
        }
        if (widget.scale != 1) {
          w = Transform.scale(scale: widget.scale + (1 - widget.scale) * v, child: w);
        }
        return w;
      },
    );
  }
}

/// Respuesta táctil: el hijo se encoge un poco mientras se mantiene pulsado.
/// No intercepta toques; el hijo sigue manejando su propio `onTap`.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.enabled = true, this.pressedScale = 0.97});

  final Widget child;
  final bool enabled;
  final double pressedScale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || Motion.reduced(context)) return widget.child;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1,
        duration: Motion.fast,
        curve: Motion.enter,
        child: widget.child,
      ),
    );
  }
}

/// Número que «cuenta» hasta su valor. Acepta texto con prefijo/sufijo
/// («28.5%», «Bs. 120», «1,240») y conserva los decimales del destino.
/// Si el texto no contiene un número, se muestra tal cual.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount(this.text, {super.key, this.style, this.duration = const Duration(milliseconds: 700), this.textAlign});

  final String text;
  final TextStyle? style;
  final Duration duration;
  final TextAlign? textAlign;

  static final _re = RegExp(r'^(\D*?)(\d[\d,]*)(\.\d+)?(.*)$');

  @override
  Widget build(BuildContext context) {
    final m = _re.firstMatch(text);
    if (m == null || Motion.reduced(context)) return Text(text, style: style, textAlign: textAlign);
    final prefix = m.group(1)!;
    final intPart = m.group(2)!;
    final frac = m.group(3);
    final suffix = m.group(4)!;
    final hasComma = intPart.contains(',');
    final target = double.parse('${intPart.replaceAll(',', '')}${frac ?? ''}');
    final decimals = frac == null ? 0 : frac.length - 1;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: duration,
      curve: Motion.enter,
      builder: (context, v, _) {
        var s = v.toStringAsFixed(decimals);
        if (hasComma) {
          final parts = s.split('.');
          final grouped = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
          s = parts.length > 1 ? '$grouped.${parts[1]}' : grouped;
        }
        return Text('$prefix$s$suffix', style: style, textAlign: textAlign);
      },
    );
  }
}

/// Transición de página común a toda la app: fundido con un leve ascenso.
/// Es corta a propósito para que navegar se sienta inmediato.
class CheckPageTransitions extends PageTransitionsBuilder {
  const CheckPageTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (Motion.reduced(context)) return child;
    final enter = CurvedAnimation(parent: animation, curve: Motion.enter, reverseCurve: Motion.exit);
    return FadeTransition(
      opacity: enter,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(enter),
        child: child,
      ),
    );
  }
}

/// Punto que «respira»: indica un proceso en curso sin ser un spinner.
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, required this.color, this.size = 10});

  final Color color;
  final double size;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
      _started = false;
    } else if (!_started) {
      _c.repeat();
      _started = true;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s * 2.4,
      height: s * 2.4,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: s * (1 + 1.4 * _c.value),
              height: s * (1 + 1.4 * _c.value),
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withValues(alpha: 0.35 * (1 - _c.value))),
            ),
            Container(width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color)),
          ],
        ),
      ),
    );
  }
}
