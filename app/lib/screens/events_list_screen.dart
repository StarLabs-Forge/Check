import 'package:flutter/material.dart';

import '../data/admin_repository.dart';
import '../data/models.dart';
import '../services/app_session.dart';
import '../services/errors.dart';
import '../services/table_watcher.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_modals.dart';
import '../widgets/admin_scaffold.dart';
import '../widgets/async_states.dart';
import 'event_detail_screen.dart';

/// "Mis Eventos" — frame "Lista de Eventos" del Figma: tabla de eventos con
/// fecha, capacidad, check-ins con barra de progreso, estado y "Ver detalle".
/// Datos reales (vista `events_with_stats`) con refresco en vivo.
class EventsListScreen extends StatefulWidget {
  const EventsListScreen({super.key});

  @override
  State<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends State<EventsListScreen> {
  late final TableWatcher _watcher;

  bool _loading = true;
  String? _error;
  List<EventItem> _events = const [];

  @override
  void initState() {
    super.initState();
    _load();
    _watcher = TableWatcher(tables: const ['tickets', 'events'], onChange: _load)..start();
  }

  @override
  void dispose() {
    _watcher.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final events = await AdminRepository.instance.listEvents();
      if (!mounted) return;
      setState(() {
        _events = events;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_events.isEmpty) _error = friendlyError(e);
      });
    }
  }

  void _retry() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _load();
  }

  Future<void> _create() async {
    final created = await showCreateEventModal(context);
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      current: AdminRoute.eventos,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.s6,
              runSpacing: AppSpacing.s4,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Mis Eventos',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.h1, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    ValueListenableBuilder<Profile?>(
                      valueListenable: AppSession.profile,
                      builder: (_, profile, _) => Text(
                        'Gestiona fechas, capacidad y accesos de ${profile?.venueName ?? ''}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  width: 220,
                  child: ElevatedButton(
                    onPressed: _create,
                    child: const Text('+ Crear evento'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            if (_loading)
              const LoadingBlock()
            else if (_error != null)
              ErrorBlock(message: _error!, onRetry: _retry)
            else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.s6),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  border: Border.all(color: AppColors.bgBorder),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Column(
                  children: [
                    const _TableHeader(),
                    const TableDivider(),
                    if (_events.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.s6),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Aún no tienes eventos. Crea el primero con "+ Crear evento".',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
                          ),
                        ),
                      )
                    else
                      for (final event in _events) ...[
                        _EventRow(event: event, onReturn: _load),
                        const TableDivider(),
                      ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                '${_events.length} ${_events.length == 1 ? 'evento' : 'eventos'} · Los datos de check-in se actualizan en tiempo real',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.caption),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.caption, fontWeight: FontWeight.w500);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s4),
      child: Row(
        children: const [
          SizedBox(width: 220, child: Text('Evento', style: style)),
          SizedBox(width: 130, child: Text('Fecha', style: style)),
          SizedBox(width: 100, child: Text('Capacidad', style: style)),
          Expanded(child: Text('Check-ins', style: style)),
          SizedBox(width: 100, child: Text('Estado', style: style)),
          SizedBox(width: 110, child: Text('Acción', style: style)),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.onReturn});

  final EventItem event;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
      child: Row(
        children: [
          SizedBox(
            width: 220,
            child: Text(
              event.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.bodyLg, fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            width: 130,
            child: Text(event.date, style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body)),
          ),
          SizedBox(
            width: 100,
            child: Text('${event.capacity}', style: const TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.body)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${event.checkins}/${event.capacity}',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.body, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  SizedBox(width: 150, child: AppProgressBar(progress: event.occupancy, height: 4)),
                ],
              ),
            ),
          ),
          SizedBox(width: 100, child: StatusBadge(event.status)),
          SizedBox(
            width: 110,
            child: TextButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: event.id)),
                );
                onReturn();
              },
              child: const Text('Ver detalle →'),
            ),
          ),
        ],
      ),
    );
  }
}
