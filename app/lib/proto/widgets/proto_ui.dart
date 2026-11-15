import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../data/proto_store.dart';

/// Colores semánticos del prototipo (sobre los tokens de CHECK).
class PColors {
  PColors._();
  static const warning = Color(0xFFFFB800);
  static const info = Color(0xFF4DA3FF);
}

class Bp {
  Bp._();
  static const double tablet = 700;
  static const double desktop = 1100;
  static bool isMobile(BuildContext c) => MediaQuery.sizeOf(c).width < tablet;
}

String money(double v) => 'Bs. ${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2)}';

String two(int n) => n.toString().padLeft(2, '0');
const _months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
String fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';
String fmtTime(DateTime d) => '${two(d.hour)}:${two(d.minute)}';
String fmtDateTime(DateTime d) => '${fmtDate(d)} · ${fmtTime(d)}';

String waitText(DateTime since) {
  final m = DateTime.now().difference(since).inMinutes;
  if (m < 1) return 'ahora';
  if (m < 60) return '$m min';
  final h = m ~/ 60;
  return h < 24 ? '$h h ${m % 60} min' : '${h ~/ 24} d';
}

/// Antigüedad: <15 min normal, <60 atención, resto urgente.
Color ageColor(DateTime since) {
  final m = DateTime.now().difference(since).inMinutes;
  if (m < 15) return AppColors.success;
  if (m < 60) return PColors.warning;
  return AppColors.error;
}

String statusLabel(OrderStatus s) => switch (s) {
      OrderStatus.awaitingPayment => 'Esperando pago',
      OrderStatus.verifying => 'En verificación',
      OrderStatus.approved => 'Aprobado',
      OrderStatus.rejected => 'Rechazado',
      OrderStatus.expired => 'Expirado',
      OrderStatus.cancelled => 'Cancelado',
    };

Color statusColor(OrderStatus s) => switch (s) {
      OrderStatus.awaitingPayment => PColors.info,
      OrderStatus.verifying => PColors.warning,
      OrderStatus.approved => AppColors.success,
      OrderStatus.rejected => AppColors.error,
      OrderStatus.expired => AppColors.textSecondary,
      OrderStatus.cancelled => AppColors.textSecondary,
    };

TextStyle ts(double size, {FontWeight w = FontWeight.w400, Color c = AppColors.textPrimary, double? h}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: w, color: c, height: h);

/// Centra el contenido con un ancho máximo → 100 % responsivo.
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({super.key, required this.child, this.maxWidth = 1100, this.scroll = true});
  final Widget child;
  final double maxWidth;
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final pad = w < Bp.tablet ? AppSpacing.s4 : AppSpacing.s6;
    final content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: EdgeInsets.all(pad), child: child),
      ),
    );
    return scroll ? SingleChildScrollView(child: content) : content;
  }
}

class PCard extends StatelessWidget {
  const PCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(AppSpacing.s4), this.color, this.border});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? color;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: border ?? AppColors.bgBorder),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(AppRadius.lg), onTap: onTap, child: box),
    );
  }
}

class Chip2 extends StatelessWidget {
  const Chip2(this.label, this.color, {super.key});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(label, style: ts(AppTextSize.caption, w: FontWeight.w600, c: color)),
      );
}

enum BtnKind { primary, secondary, danger }

class PButton extends StatelessWidget {
  const PButton(this.label, {super.key, this.onPressed, this.kind = BtnKind.primary, this.icon, this.loading = false});
  final String label;
  final VoidCallback? onPressed;
  final BtnKind kind;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Color? side) = switch (kind) {
      BtnKind.primary => (AppColors.accentPrimary, AppColors.bgPrimary, null),
      BtnKind.danger => (AppColors.error, Colors.white, null),
      BtnKind.secondary => (Colors.transparent, AppColors.textPrimary, AppColors.bgBorder),
    };
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          side: side == null ? null : BorderSide(color: side),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
        child: loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: ts(AppTextSize.body, w: FontWeight.w600, c: fg))),
              ]),
      ),
    );
  }
}

class KV extends StatelessWidget {
  const KV(this.k, this.v, {super.key, this.vColor});
  final String k;
  final String v;
  final Color? vColor;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 4, child: Text(k, style: ts(AppTextSize.body, c: AppColors.textSecondary))),
          Expanded(flex: 6, child: Text(v, textAlign: TextAlign.right, style: ts(AppTextSize.body, w: FontWeight.w500, c: vColor ?? AppColors.textPrimary))),
        ]),
      );
}

class Notice extends StatelessWidget {
  const Notice(this.text, {super.key, this.color = PColors.warning, this.icon = Icons.info_outline});
  final String text;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: ts(AppTextSize.body, h: 1.4))),
        ]),
      );
}

class H extends StatelessWidget {
  const H(this.text, {super.key, this.sub});
  final String text;
  final String? sub;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.s4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(text, style: ts(Bp.isMobile(context) ? 22 : AppTextSize.h2, w: FontWeight.w700)),
          if (sub != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(sub!, style: ts(AppTextSize.body, c: AppColors.textSecondary))),
        ]),
      );
}

/// Portada generada (no hay imágenes reales en el prototipo).
class Cover extends StatelessWidget {
  const Cover(this.hue, {super.key, this.height = 140, this.radius = AppRadius.lg});
  final int hue;
  final double height;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [HSLColor.fromAHSL(1, hue.toDouble(), 0.7, 0.25).toColor(), HSLColor.fromAHSL(1, (hue + 40) % 360, 0.6, 0.10).toColor()],
          ),
        ),
        child: Icon(Icons.nightlife, size: height * 0.38, color: Colors.white.withValues(alpha: 0.18)),
      );
}

enum ViewState { loading, error, empty, denied }

/// Estados de carga / error / vacío / acceso denegado.
class StateView extends StatelessWidget {
  const StateView(this.state, {super.key, this.message, this.onRetry});
  final ViewState state;
  final String? message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    if (state == ViewState.loading) {
      return const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator(color: AppColors.accentPrimary)));
    }
    final (icon, title, color) = switch (state) {
      ViewState.error => (Icons.error_outline, 'Algo salió mal', AppColors.error),
      ViewState.denied => (Icons.lock_outline, 'Acceso denegado', AppColors.error),
      _ => (Icons.inbox_outlined, 'Nada por aquí', AppColors.textSecondary),
    };
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s6),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(title, style: ts(AppTextSize.h3, w: FontWeight.w700)),
            if (message != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(message!, textAlign: TextAlign.center, style: ts(AppTextSize.body, c: AppColors.textSecondary, h: 1.4))),
            if (onRetry != null) Padding(padding: const EdgeInsets.only(top: 16), child: SizedBox(width: 180, child: PButton('Reintentar', kind: BtnKind.secondary, onPressed: onRetry))),
          ]),
        ),
      ),
    );
  }
}

void toast(BuildContext c, String msg, {bool error = false}) {
  ScaffoldMessenger.of(c).hideCurrentSnackBar();
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: error ? AppColors.error : AppColors.bgBorder,
    content: Text(msg, style: ts(AppTextSize.body)),
  ));
}

class NavItem {
  const NavItem(this.label, this.icon, {this.badge = 0});
  final String label;
  final IconData icon;
  final int badge;
}

/// Shell adaptativo: barra inferior (móvil) → rail (tablet) → rail extendido (web).
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.index,
    required this.onSelect,
    required this.body,
    this.onExit,
  });
  final String title;
  final String subtitle;
  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onSelect;
  final Widget body;
  final VoidCallback? onExit;

  Widget _icon(NavItem i, bool selected) {
    final icon = Icon(i.icon, color: selected ? AppColors.accentPrimary : AppColors.textSecondary);
    return i.badge > 0 ? Badge(label: Text('${i.badge}'), child: icon) : icon;
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final mobile = w < Bp.tablet;
    final extended = w >= Bp.desktop;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s4, AppSpacing.s4, AppSpacing.s4, AppSpacing.s2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('CHECK.', style: ts(20, w: FontWeight.w800, c: AppColors.accentPrimary)),
        const SizedBox(height: 2),
        Text(title, style: ts(AppTextSize.body, w: FontWeight.w600)),
        Text(subtitle, style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
      ]),
    );

    final demoBar = Container(
      width: double.infinity,
      color: PColors.warning.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Text('PROTOTIPO · datos simulados · sin pagos ni envíos reales', textAlign: TextAlign.center, style: ts(11, c: PColors.warning, w: FontWeight.w600)),
    );

    if (mobile) {
      return Scaffold(
        appBar: AppBar(
          titleSpacing: AppSpacing.s4,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: ts(AppTextSize.bodyLg, w: FontWeight.w700)),
            Text(subtitle, style: ts(11, c: AppColors.textSecondary)),
          ]),
          actions: [if (onExit != null) IconButton(tooltip: 'Cambiar experiencia', onPressed: onExit, icon: const Icon(Icons.swap_horiz))],
        ),
        body: Column(children: [demoBar, Expanded(child: body)]),
        bottomNavigationBar: NavigationBar(
          backgroundColor: AppColors.bgSurface,
          indicatorColor: AppColors.accentSubtle,
          selectedIndex: index,
          onDestinationSelected: onSelect,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            for (var i = 0; i < items.length; i++)
              NavigationDestination(icon: _icon(items[i], false), selectedIcon: _icon(items[i], true), label: items[i].label),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(children: [
        Container(
          color: AppColors.bgSurface,
          child: SafeArea(
            child: NavigationRail(
              backgroundColor: AppColors.bgSurface,
              extended: extended,
              labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
              minExtendedWidth: 220,
              selectedIndex: index,
              onDestinationSelected: onSelect,
              indicatorColor: AppColors.accentSubtle,
              selectedLabelTextStyle: ts(AppTextSize.body, w: FontWeight.w600, c: AppColors.accentPrimary),
              unselectedLabelTextStyle: ts(AppTextSize.body, c: AppColors.textSecondary),
              leading: extended
                  ? SizedBox(width: 220, child: header)
                  : Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('CHECK.', style: ts(14, w: FontWeight.w800, c: AppColors.accentPrimary))),
              trailing: onExit == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: extended
                          ? TextButton.icon(onPressed: onExit, icon: const Icon(Icons.swap_horiz, size: 18), label: const Text('Cambiar experiencia'))
                          : IconButton(tooltip: 'Cambiar experiencia', onPressed: onExit, icon: const Icon(Icons.swap_horiz)),
                    ),
              destinations: [
                for (final i in items) NavigationRailDestination(icon: _icon(i, false), selectedIcon: _icon(i, true), label: Text(i.label)),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: Column(children: [demoBar, Expanded(child: body)])),
      ]),
    );
  }
}
