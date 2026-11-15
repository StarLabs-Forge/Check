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

/// "Detalle de Evento" — cabecera con estado + acciones, 3 métricas (Total,
/// Ingresados, Pendientes), barra de ocupación y lista de invitados con
/// buscador. Datos reales de Supabase, en vivo.
///
/// Ciclo de vida del evento (lo valida el trigger `guard_event`):
/// borrador → activo → en vivo → cerrado. "Cerrado" es definitivo.
class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final _repo = AdminRepository.instance;
  final _searchCtrl = TextEditingController();
  late final TableWatcher _watcher;

  String _query = '';
  bool _loading = true;
  bool _changingStatus = false;
  String? _error;
  EventItem? _event;
  List<GuestItem> _allGuests = const [];

  @override
  void initState() {
    super.initState();
    _load();
    _watcher = TableWatcher(tables: const ['tickets', 'events'], onChange: _load)..start();
  }

  @override
  void dispose() {
    _watcher.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final event = await _repo.getEvent(widget.eventId);
      if (event == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Este evento no existe o ya no tienes acceso.';
        });
        return;
      }
      final guests = await _repo.listTickets(eventId: widget.eventId, limit: 1000);
      if (!mounted) return;
      setState(() {
        _event = event;
        _allGuests = guests;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_event == null) _error = friendlyError(e);
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

  List<GuestItem> get _guests {
    if (_query.isEmpty) return _allGuests;
    final q = _query.toLowerCase();
    return _allGuests.where((g) => g.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _changeStatus(String status, {required String okMessage}) async {
    setState(() => _changingStatus = true);
    try {
      await _repo.setEventStatus(widget.eventId, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(okMessage)));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
    if (mounted) setState(() => _changingStatus = false);
  }

  Future<void> _closeEvent(EventItem event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: const Text('¿Cerrar el evento?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          '"${event.name}" quedará finalizado y ya no se podrá modificar ni emitir más tickets. Esta acción no se puede deshacer.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cerrar evento'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _changeStatus('finished', okMessage: 'Evento "${event.name}" cerrado');
    }
  }

  Future<void> _generateTickets(EventItem event) async {
    final issued = await showGenerateTicketsModal(context, event: event);
    if (issued == true) _load();
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
            if (Navigator.of(context).canPop())
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s2),
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, size: 16, color: AppColors.textSecondary),
                  label: const Text('Volver a Eventos'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary, padding: EdgeInsets.zero),
                ),
              ),
            if (_loading)
              const LoadingBlock()
            else if (_error != null || _event == null)
              ErrorBlock(message: _error ?? 'No se pudo cargar el evento.', onRetry: _retry)
            else
              ..._content(_event!),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(EventItem event) {
    final pendientes = event.pending;
    final guests = _guests;

    return [
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.s6,
        runSpacing: AppSpacing.s4,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    event.name,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.h1, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: AppSpacing.s4),
                  StatusBadge(event.status),
                ],
              ),
              const SizedBox(height: AppSpacing.s2),
              ValueListenableBuilder<Profile?>(
                valueListenable: AppSession.profile,
                builder: (_, profile, _) => Text(
                  '${event.date} · ${event.time} · ${profile?.venueName ?? ''}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
                ),
              ),
            ],
          ),
          if (event.canClose)
            SizedBox(
              width: 180,
              child: OutlinedButton(
                onPressed: _changingStatus ? null : () => _closeEvent(event),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
                child: const Text('Cerrar evento'),
              ),
            ),
          if (event.canActivate)
            SizedBox(
              width: 200,
              child: OutlinedButton(
                onPressed: _changingStatus
                    ? null
                    : () => _changeStatus('active', okMessage: 'Evento activado: ya puede recibir accesos'),
                child: const Text('Activar evento'),
              ),
            ),
          if (event.canGoLive)
            SizedBox(
              width: 200,
              child: OutlinedButton(
                onPressed: _changingStatus
                    ? null
                    : () => _changeStatus('live', okMessage: 'Evento en vivo'),
                child: const Text('Iniciar evento'),
              ),
            ),
          if (event.canIssueTickets)
            SizedBox(
              width: 232,
              child: ElevatedButton(
                onPressed: () => _generateTickets(event),
                child: const Text('Generar tickets'),
              ),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.s5),
      Wrap(
        spacing: AppSpacing.s6,
        runSpacing: AppSpacing.s6,
        children: [
          MetricCard(label: 'Total', value: '${event.capacity}', trendLabel: '${event.ticketsTotal} tickets emitidos', width: 358),
          MetricCard(
            label: 'Ingresados',
            value: '${event.checkins}',
            trendLabel: event.checkinsLastHour > 0 ? '↑ ${event.checkinsLastHour} en la última hora' : 'Sin cambios',
            trendColor: event.checkinsLastHour > 0 ? AppColors.accentPrimary : null,
            width: 359,
          ),
          MetricCard(label: 'Pendientes', value: '$pendientes', trendLabel: 'Sin cambios', width: 359),
        ],
      ),
      const SizedBox(height: AppSpacing.s5),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppProgressBar(progress: event.occupancy, height: 8),
          const SizedBox(height: AppSpacing.s2),
          Text(
            '${(event.occupancy * 100).toStringAsFixed(1)}% de ocupación · $pendientes invitados pendientes',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.caption),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.s5),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.s6),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          border: Border.all(color: AppColors.bgBorder),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.s4,
              runSpacing: AppSpacing.s3,
              children: [
                const Text(
                  'Lista de Invitados',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.h3, fontWeight: FontWeight.w600),
                ),
                SearchField(
                  hint: 'Buscar por nombre',
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            const _GuestTableHeader(),
            const TableDivider(),
            if (guests.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
                child: Text(
                  _query.isEmpty
                      ? 'Aún no hay invitados registrados para este evento.'
                      : 'No se encontraron invitados con ese nombre.',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
                ),
              )
            else
              for (final guest in guests) ...[
                _GuestRow(guest: guest),
                const TableDivider(),
              ],
          ],
        ),
      ),
    ];
  }
}

class _GuestTableHeader extends StatelessWidget {
  const _GuestTableHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.caption, fontWeight: FontWeight.w500);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s3, top: AppSpacing.s3),
      child: Row(
        children: const [
          Expanded(flex: 5, child: Text('Invitado', style: style)),
          Expanded(flex: 3, child: Text('Estado', style: style)),
          Expanded(flex: 2, child: Text('Hora de ingreso', style: style)),
        ],
      ),
    );
  }
}

class _GuestRow extends StatelessWidget {
  const _GuestRow({required this.guest});

  final GuestItem guest;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              guest.name,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.body, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(flex: 3, child: Align(alignment: Alignment.centerLeft, child: StatusBadge(guest.status))),
          Expanded(
            flex: 2,
            child: Text(guest.time, style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body)),
          ),
        ],
      ),
    );
  }
}
