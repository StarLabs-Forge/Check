import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/check_logo.dart';
import 'login_screen.dart';

/// Pantalla inicial del Admin — implementa el frame "Dashboard Principal"
/// del archivo de Figma (🖥️ Dashboard Web, node 25:2), adaptado a Flutter:
/// misma paleta, tipografía Inter, espaciados y componentes (Metric Card,
/// Badge, Progress Bar, Toast, Avatar) definidos ahí.
///
/// Nota: los íconos de navegación del Figma vienen como SVG exportado
/// (expiran en ~7 días desde el link de Figma); acá se usan los Material
/// Icons más cercanos como placeholder — cuando el set de íconos final esté
/// exportado como asset del proyecto, se reemplazan 1 a 1 en `_NavItem`.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _NavRoute { dashboard, eventos, tickets, configuracion }

class _HomeScreenState extends State<HomeScreen> {
  _NavRoute _current = _NavRoute.dashboard;
  bool _showToast = true;

  static const double _wideBreakpoint = 900;

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      drawerEnableOpenDragGesture: false,
      drawer: LayoutBuilder(
        builder: (context, constraints) {
          return const Drawer(
            backgroundColor: AppColors.bgSurface,
            child: SafeArea(child: _SidebarContent()),
          );
        },
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
                        child: _SidebarContent(
                          current: _current,
                          onSelect: (r) => setState(() => _current = r),
                          onLogout: _logout,
                        ),
                      ),
                    ),
                  Expanded(
                    child: SafeArea(
                      left: false,
                      child: _DashboardContent(
                        showMenuButton: !isWide,
                        onMenuPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
                  ),
                ],
              ),
              if (_showToast)
                Positioned(
                  top: 24,
                  right: 24,
                  child: _ToastNotification(
                    onDismiss: () => setState(() => _showToast = false),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SidebarContent extends StatelessWidget {
  const _SidebarContent({this.current = _NavRoute.dashboard, this.onSelect, this.onLogout});

  final _NavRoute current;
  final ValueChanged<_NavRoute>? onSelect;
  final VoidCallback? onLogout;

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
                active: current == _NavRoute.dashboard,
                onTap: () => onSelect?.call(_NavRoute.dashboard),
              ),
              const SizedBox(height: AppSpacing.s2),
              _NavItem(
                icon: Icons.calendar_today_outlined,
                label: 'Eventos',
                active: current == _NavRoute.eventos,
                onTap: () => onSelect?.call(_NavRoute.eventos),
              ),
              const SizedBox(height: AppSpacing.s2),
              _NavItem(
                icon: Icons.confirmation_number_outlined,
                label: 'Tickets',
                active: current == _NavRoute.tickets,
                onTap: () => onSelect?.call(_NavRoute.tickets),
              ),
              const SizedBox(height: AppSpacing.s2),
              _NavItem(
                icon: Icons.settings_outlined,
                label: 'Configuración',
                active: current == _NavRoute.configuracion,
                onTap: () => onSelect?.call(_NavRoute.configuracion),
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
              const _Avatar(initials: 'NF'),
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
                  onPressed: onLogout,
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, this.size = 40});

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

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.showMenuButton, required this.onMenuPressed});

  final bool showMenuButton;
  final VoidCallback onMenuPressed;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(showMenuButton: showMenuButton, onMenuPressed: onMenuPressed),
          const SizedBox(height: AppSpacing.s8),
          Wrap(
            spacing: AppSpacing.s6,
            runSpacing: AppSpacing.s6,
            children: const [
              _MetricCard(label: 'Eventos activos', value: '1', trend: _Trend.neutral, trendLabel: 'Sin cambios'),
              _MetricCard(label: 'Check-ins', value: '143', trend: _Trend.positive, trendLabel: '↑ 12 en la última hora'),
              _MetricCard(label: 'Ocupación', value: '71.5%', trend: _Trend.positive, trendLabel: '143 de 200 plazas'),
              _MetricCard(label: 'Cancelados', value: '1', trend: _Trend.negative, trendLabel: '↓ 1 cancelación'),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Wrap(
            spacing: AppSpacing.s6,
            runSpacing: AppSpacing.s6,
            children: const [
              _EventProgressCard(),
              _RecentActivityCard(),
            ],
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.showMenuButton, required this.onMenuPressed});

  final bool showMenuButton;
  final VoidCallback onMenuPressed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.s6,
      runSpacing: AppSpacing.s4,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showMenuButton)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.s3),
                child: IconButton(
                  onPressed: onMenuPressed,
                  icon: const Icon(Icons.menu, color: AppColors.textPrimary),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Bienvenido, Napoleón Flores',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppTextSize.h1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: AppSpacing.s2),
                Text(
                  'Viernes, 12 de septiembre de 2025 · Dharma Club',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
                ),
              ],
            ),
          ],
        ),
        SizedBox(
          width: 340,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Buscar',
                style: TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.caption, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: AppSpacing.s2),
              TextField(
                style: const TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.body),
                decoration: InputDecoration(
                  hintText: 'Buscar eventos',
                  prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                  contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s3, horizontal: AppSpacing.s3),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _Trend { positive, negative, neutral }

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.trend,
    required this.trendLabel,
  });

  final String label;
  final String value;
  final _Trend trend;
  final String trendLabel;

  @override
  Widget build(BuildContext context) {
    final trendColor = switch (trend) {
      _Trend.positive => AppColors.accentPrimary,
      _Trend.negative => AppColors.error,
      _Trend.neutral => AppColors.textSecondary,
    };

    return Container(
      width: 250,
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
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.caption, height: 1.2),
          ),
          const SizedBox(height: AppSpacing.s1),
          Text(
            value,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w700, height: 1.15),
          ),
          const SizedBox(height: AppSpacing.s1),
          Text(
            trendLabel,
            style: TextStyle(color: trendColor, fontSize: AppTextSize.caption, height: 1.2),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accentSubtle,
        border: Border.all(color: AppColors.accentPrimary),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: const TextStyle(color: AppColors.accentPrimary, fontSize: AppTextSize.caption, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _EventProgressCard extends StatelessWidget {
  const _EventProgressCard();

  @override
  Widget build(BuildContext context) {
    const progress = 0.715;
    return Container(
      width: 680,
      padding: const EdgeInsets.all(AppSpacing.s8),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border.all(color: AppColors.bgBorder),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                'Progreso del Evento',
                style: TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.h3, fontWeight: FontWeight.w600),
              ),
              SizedBox(width: AppSpacing.s3),
              _StatusBadge(label: 'Activo'),
            ],
          ),
          const SizedBox(height: AppSpacing.s6),
          const Text(
            'Eclipse Party',
            style: TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.h1, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.s2),
          const Text(
            '12 Sep 2025 · 22:00',
            style: TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
          ),
          const SizedBox(height: AppSpacing.s4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: const [
              Text('143', style: TextStyle(color: AppColors.accentPrimary, fontSize: 64, fontWeight: FontWeight.w700)),
              SizedBox(width: AppSpacing.s3),
              Text('/ 200', style: TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.h1)),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.bgInput,
              valueColor: const AlwaysStoppedAnimation(AppColors.accentPrimary),
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          const Text(
            '71.5% Ingresados · 57 Pendientes',
            style: TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
          ),
          const SizedBox(height: AppSpacing.s6),
          SizedBox(
            width: 160,
            child: OutlinedButton(
              onPressed: () {},
              child: const Text('Ver detalle'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard();

  static const _entries = [
    ('AC', 'Andrés Condori', '22:18'),
    ('DA', 'Diego Alvarado', '22:05'),
    ('RM', 'Rodrigo Mamani', '21:41'),
    ('VQ', 'Valentina Quispe', '21:34'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 420,
      padding: const EdgeInsets.all(AppSpacing.s6),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border.all(color: AppColors.bgBorder),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Actividad reciente',
            style: TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.h3, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.s1),
          const Text(
            'Ingresos en tiempo real',
            style: TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.caption),
          ),
          const SizedBox(height: AppSpacing.s6),
          for (final entry in _entries) ...[
            _ActivityRow(initials: entry.$1, name: entry.$2, time: entry.$3),
            if (entry != _entries.last) const SizedBox(height: AppSpacing.s4),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.initials, required this.name, required this.time});

  final String initials;
  final String name;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Avatar(initials: initials),
        const SizedBox(width: AppSpacing.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.body, fontWeight: FontWeight.w500)),
              const SizedBox(height: AppSpacing.s1),
              const Text('Acceso permitido', style: TextStyle(color: AppColors.accentPrimary, fontSize: AppTextSize.caption)),
            ],
          ),
        ),
        Text(time, style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.caption)),
      ],
    );
  }
}

class _ToastNotification extends StatelessWidget {
  const _ToastNotification({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border.all(color: AppColors.bgBorder),
        borderRadius: BorderRadius.circular(AppRadius.input),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Stack(
        children: [
          Positioned(
            left: -12,
            top: 9,
            child: Container(
              width: 3,
              height: 44,
              decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(AppRadius.full)),
            ),
          ),
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                child: const Icon(Icons.check_circle, color: AppColors.success, size: 22),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'Andrés Condori',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.body, fontWeight: FontWeight.w600, height: 1.2),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Acaba de ingresar · 22:18',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.caption, height: 1.2),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: onDismiss,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, color: AppColors.textSecondary, size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
