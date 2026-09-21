import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_scaffold.dart';

/// Pantalla inicial del Admin — implementa el frame "Dashboard Principal"
/// del archivo de Figma (🖥️ Dashboard Web, node 25:2), adaptado a Flutter:
/// misma paleta, tipografía Inter, espaciados y componentes (Metric Card,
/// Badge, Progress Bar, Toast, Avatar) definidos ahí.
///
/// El layout de sidebar/navegación compartido con Eventos y Tickets vive en
/// `AdminScaffold` (lib/widgets/admin_scaffold.dart).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showToast = true;

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      current: AdminRoute.dashboard,
      body: const _DashboardContent(),
      overlay: _showToast
          ? Positioned(
              top: 24,
              right: 24,
              child: _ToastNotification(onDismiss: () => setState(() => _showToast = false)),
            )
          : null,
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header(),
          const SizedBox(height: AppSpacing.s8),
          Wrap(
            spacing: AppSpacing.s6,
            runSpacing: AppSpacing.s6,
            children: const [
              MetricCard(label: 'Eventos activos', value: '1', trendLabel: 'Sin cambios'),
              MetricCard(label: 'Check-ins', value: '143', trendLabel: '↑ 12 en la última hora', trendColor: AppColors.accentPrimary),
              MetricCard(label: 'Ocupación', value: '71.5%', trendLabel: '143 de 200 plazas', trendColor: AppColors.accentPrimary),
              MetricCard(label: 'Cancelados', value: '1', trendLabel: '↓ 1 cancelación', trendColor: AppColors.error),
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
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.s6,
      runSpacing: AppSpacing.s4,
      children: const [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
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
        SizedBox(
          width: 340,
          child: SearchField(hint: 'Buscar eventos'),
        ),
      ],
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
              StatusBadge(BadgeStatus.activo),
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
          const AppProgressBar(progress: progress, height: 8),
          const SizedBox(height: AppSpacing.s3),
          const Text(
            '71.5% Ingresados · 57 Pendientes',
            style: TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
          ),
          const SizedBox(height: AppSpacing.s6),
          SizedBox(
            width: 160,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pushNamed('/eventos'),
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
        Avatar(initials: initials),
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
