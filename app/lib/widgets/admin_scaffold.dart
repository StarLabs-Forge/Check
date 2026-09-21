import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'check_logo.dart';

/// Rutas de la navegación lateral del panel Admin. `configuracion` todavía
/// no tiene diseño en Figma (solo aparece como ítem de sidebar) — al
/// seleccionarla se muestra un aviso en vez de navegar a una pantalla vacía.
enum AdminRoute { dashboard, eventos, tickets, configuracion }

/// Layout compartido del panel Admin (Dashboard / Eventos / Tickets):
/// sidebar fija de 220px en desktop, Drawer en mobile/tablet angosto,
/// mismo header de identidad + navegación + perfil en las 3 pantallas,
/// tal como lo define Figma (mismo componente "Barra lateral" repetido en
/// los frames "Dashboard Principal", "Lista de Eventos", "Detalle de
/// Evento" y "Admin · Tickets").
///
/// Cada pantalla solo provee su `body` (ya scrolleable si lo necesita) y le
/// dice a este scaffold cuál ítem de nav está activo; el scaffold se encarga
/// de la navegación entre ellas.
class AdminScaffold extends StatelessWidget {
  const AdminScaffold({
    super.key,
    required this.current,
    required this.body,
    this.overlay,
  });

  final AdminRoute current;
  final Widget body;

  /// Contenido flotante opcional sobre el body (ej. el Toast del Dashboard).
  final Widget? overlay;

  static const double _wideBreakpoint = 900;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      drawerEnableOpenDragGesture: false,
      drawer: Drawer(
        backgroundColor: AppColors.bgSurface,
        child: SafeArea(child: _SidebarContent(current: current)),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _wideBreakpoint;
          return Stack(
            children: [
              Row(
                children: [
                  if (isWide)
                    Container(
                      width: 220,
                      color: AppColors.bgSurface,
                      child: SafeArea(
                        right: false,
                        child: _SidebarContent(current: current),
                      ),
                    ),
                  Expanded(
                    child: SafeArea(
                      left: false,
                      child: Builder(
                        builder: (innerContext) => _BodyWithMenu(
                          showMenuButton: !isWide,
                          onMenuPressed: () => Scaffold.of(innerContext).openDrawer(),
                          child: body,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (overlay != null) overlay!,
            ],
          );
        },
      ),
    );
  }
}

/// Inserta un botón de menú (hamburguesa) arriba del body cuando la sidebar
/// colapsa a Drawer, sin que cada pantalla tenga que manejarlo.
class _BodyWithMenu extends StatelessWidget {
  const _BodyWithMenu({required this.showMenuButton, required this.onMenuPressed, required this.child});

  final bool showMenuButton;
  final VoidCallback onMenuPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!showMenuButton) return child;
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: onMenuPressed,
            icon: const Icon(Icons.menu, color: AppColors.textPrimary),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _SidebarContent extends StatelessWidget {
  const _SidebarContent({required this.current});

  final AdminRoute current;

  void _logout(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  void _go(BuildContext context, AdminRoute route) {
    if (route == current) return;
    if (route == AdminRoute.configuracion) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuración: pantalla pendiente de diseño en Figma')),
      );
      return;
    }
    final routeName = switch (route) {
      AdminRoute.dashboard => '/home',
      AdminRoute.eventos => '/eventos',
      AdminRoute.tickets => '/tickets',
      AdminRoute.configuracion => '/home',
    };
    Navigator.of(context).pushReplacementNamed(routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.s4, AppSpacing.s4, AppSpacing.s4, 0),
          child: CheckLogo(subtitle: 'Dharma Club'),
        ),
        const SizedBox(height: AppSpacing.s8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
          child: Column(
            children: [
              _NavItem(
                icon: Icons.grid_view_rounded,
                label: 'Dashboard',
                active: current == AdminRoute.dashboard,
                onTap: () => _go(context, AdminRoute.dashboard),
              ),
              const SizedBox(height: AppSpacing.s2),
              _NavItem(
                icon: Icons.calendar_today_outlined,
                label: 'Eventos',
                active: current == AdminRoute.eventos,
                onTap: () => _go(context, AdminRoute.eventos),
              ),
              const SizedBox(height: AppSpacing.s2),
              _NavItem(
                icon: Icons.confirmation_number_outlined,
                label: 'Tickets',
                active: current == AdminRoute.tickets,
                onTap: () => _go(context, AdminRoute.tickets),
              ),
              const SizedBox(height: AppSpacing.s2),
              _NavItem(
                icon: Icons.settings_outlined,
                label: 'Configuración',
                active: current == AdminRoute.configuracion,
                onTap: () => _go(context, AdminRoute.configuracion),
              ),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Avatar(initials: 'NF'),
              const SizedBox(height: AppSpacing.s3),
              const Text(
                'Napoleón Flores',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppTextSize.body,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.s1),
              const Text(
                'Administrador',
                style: TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.caption),
              ),
              const SizedBox(height: AppSpacing.s3),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _logout(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.bgBorder),
                  ),
                  child: const Text('Cerrar sesión'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accentPrimary : AppColors.textSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
          decoration: BoxDecoration(
            color: active ? AppColors.accentSubtle : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              if (active)
                Positioned(
                  left: -12,
                  child: Container(
                    width: 3,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.accentPrimary,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                ),
              Row(
                children: [
                  Icon(icon, size: 22, color: color),
                  const SizedBox(width: AppSpacing.s3),
                  Text(
                    label,
                    style: TextStyle(color: color, fontSize: AppTextSize.body, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar circular de iniciales — compartido por la sidebar y las listas de
/// actividad/invitados.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.initials, this.size = 40});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.accentSubtle,
        border: Border.all(color: AppColors.accentPrimary, width: 1.5),
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: AppColors.accentPrimary,
          fontWeight: FontWeight.w700,
          fontSize: AppTextSize.body,
        ),
      ),
    );
  }
}

/// Estados semánticos del Badge (Figma "Badge", 6 variantes: Activo,
/// Borrador, Cerrado, Ingresó, Pendiente, Cancelado). Activo e Ingresó
/// comparten estilo (verde), igual que Cerrado y Cancelado (rojo).
enum BadgeStatus { activo, borrador, cerrado, ingreso, pendiente, cancelado }

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});

  final BadgeStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, border, text, label) = switch (status) {
      BadgeStatus.activo => (AppColors.accentSubtle, AppColors.accentPrimary, AppColors.accentPrimary, 'Activo'),
      BadgeStatus.ingreso => (AppColors.accentSubtle, AppColors.accentPrimary, AppColors.accentPrimary, 'Ingresó'),
      BadgeStatus.borrador => (AppColors.bgDraft, AppColors.textDisabled, AppColors.textSecondary, 'Borrador'),
      BadgeStatus.pendiente => (AppColors.bgDraft, AppColors.textDisabled, AppColors.textSecondary, 'Pendiente'),
      BadgeStatus.cerrado => (AppColors.bgDanger, AppColors.error, AppColors.error, 'Cerrado'),
      BadgeStatus.cancelado => (AppColors.bgDanger, AppColors.error, AppColors.error, 'Cancelado'),
    };
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(color: text, fontSize: AppTextSize.caption, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// Metric Card compartida (Figma "Metric Card", 220×110, 3 tendencias).
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.trendLabel,
    this.trendColor,
    this.width = 220,
  });

  final String label;
  final String value;
  final String trendLabel;
  final Color? trendColor;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 110),
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border.all(color: AppColors.bgBorder),
        borderRadius: BorderRadius.circular(AppRadius.metric),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.caption, height: 1.2)),
          const SizedBox(height: AppSpacing.s1),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w700, height: 1.15)),
          const SizedBox(height: AppSpacing.s1),
          Text(
            trendLabel,
            style: TextStyle(color: trendColor ?? AppColors.textSecondary, fontSize: AppTextSize.caption, height: 1.2),
          ),
        ],
      ),
    );
  }
}

/// Barra de progreso (Figma "Progress Bar", track + relleno verde), usada
/// tanto en la tabla (4px) como en el resumen de un evento (8px).
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({super.key, required this.progress, this.height = 8});

  /// 0.0 a 1.0
  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: LinearProgressIndicator(
        value: progress.clamp(0, 1),
        minHeight: height,
        backgroundColor: AppColors.bgInput,
        valueColor: const AlwaysStoppedAnimation(AppColors.accentPrimary),
      ),
    );
  }
}

/// Campo de búsqueda de 48px con ícono (Figma "Input", tipo Search).
class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.hint, this.controller, this.onChanged});

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 48,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.body),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
          contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s3, horizontal: AppSpacing.s3),
        ),
      ),
    );
  }
}

/// Fila de un divisor de tabla (línea de 1px, `bg-border`).
class TableDivider extends StatelessWidget {
  const TableDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: AppColors.bgBorder);
  }
}
