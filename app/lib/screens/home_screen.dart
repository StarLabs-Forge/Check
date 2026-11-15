import 'package:flutter/material.dart';

import '../data/admin_repository.dart';
import '../data/models.dart';
import '../services/app_session.dart';
import '../services/errors.dart';
import '../services/table_watcher.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/admin_scaffold.dart';
import '../widgets/async_states.dart';

/// Pantalla inicial del Admin — frame "Dashboard Principal" del Figma.
/// Datos reales de Supabase y actualización en vivo vía Realtime: cada
/// check-in (tabla `tickets`) refresca contadores, progreso y actividad.
///
/// El layout de sidebar/navegación compartido vive en `AdminScaffold`.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repo = AdminRepository.instance;
  late final TableWatcher _watcher;

  bool _loading = true;
  String? _error;

  List<EventItem> _events = const [];
  EventItem? _featured;
  List<GuestItem> _recent = const [];

  /// Último check-in conocido; sirve para disparar el toast solo con ingresos
  /// nuevos (no en la carga inicial).
  String? _lastCheckinId;
  GuestItem? _toastGuest;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
    _watcher = TableWatcher(tables: const ['tickets', 'events'], onChange: () => _load())..start();
  }

  @override
  void dispose() {
    _watcher.dispose();
    super.dispose();
  }

  /// Evento "destacado" del dashboard: el que está en vivo; si no, el activo
  /// más próximo (o el último activo); si no hay, el más reciente.
  static EventItem? pickFeatured(List<EventItem> events) {
    if (events.isEmpty) return null;
    for (final e in events) {
      if (e.isLive) return e;
    }
    final active = events.where((e) => e.isActive).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    if (active.isNotEmpty) {
      final now = DateTime.now().toUtc();
      return active.firstWhere((e) => e.endsAt.isAfter(now), orElse: () => active.last);
    }
    return events.first; // vienen ordenados del más reciente al más antiguo
  }

  Future<void> _load({bool initial = false}) async {
    try {
      final events = await _repo.listEvents();
      final featured = pickFeatured(events);
      final recent = featured == null ? <GuestItem>[] : await _repo.recentCheckins(featured.id);
      if (!mounted) return;

      final newest = recent.isEmpty ? null : recent.first;
      final isNewCheckin = !initial && newest != null && newest.id != _lastCheckinId;

      setState(() {
        _events = events;
        _featured = featured;
        _recent = recent;
        _loading = false;
        _error = null;
        if (isNewCheckin) _toastGuest = newest;
        _lastCheckinId = newest?.id ?? _lastCheckinId;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        // Si ya había datos, un fallo de refresco en vivo no los reemplaza.
        if (_events.isEmpty) _error = friendlyError(e);
      });
    }
  }

  void _retry() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _load(initial: true);
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      current: AdminRoute.dashboard,
      body: _loading
          ? const LoadingBlock()
          : _error != null
              ? ErrorBlock(message: _error!, onRetry: _retry)
              : _DashboardContent(events: _events, featured: _featured, recent: _recent),
      overlay: _toastGuest == null
          ? null
          : Positioned(
              top: 24,
              right: 24,
              child: _ToastNotification(
                guest: _toastGuest!,
                onDismiss: () => setState(() => _toastGuest = null),
              ),
            ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.events, required this.featured, required this.recent});

  final List<EventItem> events;
  final EventItem? featured;
  final List<GuestItem> recent;

  @override
  Widget build(BuildContext context) {
    final f = featured;
    final activeEvents = events.where((e) => e.isOpen).length;
    final checkins = f?.checkins ?? 0;
    final lastHour = f?.checkinsLastHour ?? 0;
    final occupancyPct = f == null ? 0.0 : f.occupancy * 100;

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
            children: [
              MetricCard(label: 'Eventos activos', value: '$activeEvents', trendLabel: 'Sin cambios'),
              MetricCard(
                label: 'Check-ins',
                value: '$checkins',
                trendLabel: lastHour > 0 ? '↑ $lastHour en la última hora' : 'Sin cambios',
                trendColor: lastHour > 0 ? AppColors.accentPrimary : null,
              ),
              MetricCard(
                label: 'Ocupación',
                value: '${occupancyPct.toStringAsFixed(1)}%',
                trendLabel: f == null ? 'Sin evento' : '$checkins de ${f.capacity} plazas',
                trendColor: f == null ? null : AppColors.accentPrimary,
              ),
              MetricCard(
                label: 'Cancelados',
                value: '${f?.ticketsCancelled ?? 0}',
                trendLabel: (f?.ticketsCancelled ?? 0) > 0 ? '↓ ${f!.ticketsCancelled} cancelación(es)' : 'Sin cambios',
                trendColor: (f?.ticketsCancelled ?? 0) > 0 ? AppColors.error : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          if (f == null)
            const _EmptyState()
          else
            Wrap(
              spacing: AppSpacing.s6,
              runSpacing: AppSpacing.s6,
              children: [
                _EventProgressCard(event: f),
                _RecentActivityCard(entries: recent),
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
    return ValueListenableBuilder<Profile?>(
      valueListenable: AppSession.profile,
      builder: (context, profile, _) {
        return Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.s6,
          runSpacing: AppSpacing.s4,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Bienvenido, ${profile?.fullName ?? ''}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppTextSize.h1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  '${Fmt.longToday()} · ${profile?.venueName ?? ''}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s8),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border.all(color: AppColors.bgBorder),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Todavía no tienes eventos',
            style: TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.h3, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.s2),
          const Text(
            'Crea tu primer evento para empezar a emitir tickets y controlar el acceso.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
          ),
          const SizedBox(height: AppSpacing.s6),
          SizedBox(
            width: 200,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pushReplacementNamed('/eventos'),
              child: const Text('Ir a Eventos'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventProgressCard extends StatelessWidget {
  const _EventProgressCard({required this.event});

  final EventItem event;

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              const Text(
                'Progreso del Evento',
                style: TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.h3, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: AppSpacing.s3),
              StatusBadge(event.status),
            ],
          ),
          const SizedBox(height: AppSpacing.s6),
          Text(
            event.name,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.h1, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            '${event.date} · ${event.time}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
          ),
          const SizedBox(height: AppSpacing.s4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${event.checkins}',
                style: const TextStyle(color: AppColors.accentPrimary, fontSize: 64, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: AppSpacing.s3),
              Text(
                '/ ${event.capacity}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.h1),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          AppProgressBar(progress: event.occupancy, height: 8),
          const SizedBox(height: AppSpacing.s3),
          Text(
            '${(event.occupancy * 100).toStringAsFixed(1)}% Ingresados · ${event.pending} Pendientes',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
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
  const _RecentActivityCard({required this.entries});

  final List<GuestItem> entries;

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
          if (entries.isEmpty)
            const Text(
              'Aún no hay ingresos registrados.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
            )
          else
            for (var i = 0; i < entries.length; i++) ...[
              _ActivityRow(guest: entries[i]),
              if (i != entries.length - 1) const SizedBox(height: AppSpacing.s4),
            ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.guest});

  final GuestItem guest;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Avatar(initials: Fmt.initials(guest.name)),
        const SizedBox(width: AppSpacing.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                guest.name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppTextSize.body,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.s1),
              const Text(
                'Acceso permitido',
                style: TextStyle(color: AppColors.accentPrimary, fontSize: AppTextSize.caption),
              ),
            ],
          ),
        ),
        Text(guest.time, style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.caption)),
      ],
    );
  }
}

class _ToastNotification extends StatelessWidget {
  const _ToastNotification({required this.guest, required this.onDismiss});

  final GuestItem guest;
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
                  children: [
                    Text(
                      guest.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: AppTextSize.body,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Acaba de ingresar · ${guest.time}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.caption, height: 1.2),
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
