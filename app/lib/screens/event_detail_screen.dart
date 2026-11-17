import 'package:flutter/material.dart';
import '../data/mock_admin_data.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_modals.dart';
import '../widgets/admin_scaffold.dart';

/// "Detalle de Evento" — implementa el frame "Detalle de Evento — Eclipse
/// Party" (node 27:109): cabecera con estado + acciones (Cerrar evento /
/// Generar tickets), 3 métricas (Total, Ingresados, Pendientes), barra de
/// ocupación y lista de invitados con buscador. Datos mock — sin Supabase
/// todavía, así que "Cerrar evento" y "Generar tickets" solo simulan.
class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  EventItem get _event => mockEvents.firstWhere(
        (e) => e.id == widget.eventId,
        orElse: () => mockEvents.first,
      );

  List<GuestItem> get _guests {
    // Solo "Eclipse Party" tiene invitados de ejemplo cargados en el mock;
    // los demás eventos muestran la lista vacía hasta tener datos reales.
    final all = _event.id == 'eclipse-party' ? mockEclipseGuests : const <GuestItem>[];
    if (_query.isEmpty) return all;
    return all.where((g) => g.name.toLowerCase().contains(_query.toLowerCase())).toList();
  }

  void _closeEvent() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Evento "${_event.name}" cerrado (simulado) — falta conectar Supabase')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    final pendientes = event.capacity - event.checkins;

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
                    Text(
                      '${event.date} · ${event.time} · Dharma Club',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
                    ),
                  ],
                ),
                SizedBox(
                  width: 180,
                  child: OutlinedButton(
                    onPressed: _closeEvent,
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
                    child: const Text('Cerrar evento'),
                  ),
                ),
                SizedBox(
                  width: 232,
                  child: ElevatedButton(
                    onPressed: () => showGenerateTicketsModal(context, eventName: event.name),
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
                MetricCard(label: 'Total', value: '${event.capacity}', trendLabel: 'Sin cambios', width: 358),
                MetricCard(
                  label: 'Ingresados',
                  value: '${event.checkins}',
                  trendLabel: '↑ 12 en la última hora',
                  trendColor: AppColors.accentPrimary,
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
                  if (_guests.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.s6),
                      child: Text(
                        'Aún no hay invitados registrados para este evento.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
                      ),
                    )
                  else
                    for (final guest in _guests) ...[
                      _GuestRow(guest: guest),
                      const TableDivider(),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
