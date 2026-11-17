import 'package:flutter/material.dart';
import '../data/mock_admin_data.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_modals.dart';
import '../widgets/admin_scaffold.dart';
import 'event_detail_screen.dart';

/// "Mis Eventos" — implementa el frame "Lista de Eventos" (node 26:74) del
/// Figma: tabla de eventos con fecha, capacidad, check-ins con barra de
/// progreso, estado (Badge) y acción "Ver detalle". Datos mock — sin
/// Supabase todavía.
class EventsListScreen extends StatelessWidget {
  const EventsListScreen({super.key});

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
                  children: const [
                    Text(
                      'Mis Eventos',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.h1, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: AppSpacing.s2),
                    Text(
                      'Gestiona fechas, capacidad y accesos de Dharma Club',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
                    ),
                  ],
                ),
                SizedBox(
                  width: 220,
                  child: ElevatedButton(
                    onPressed: () => showCreateEventModal(context),
                    child: const Text('+ Crear evento'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.s6),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                border: Border.all(color: AppColors.bgBorder),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    children: [
                      const _TableHeader(),
                      const TableDivider(),
                      for (final event in mockEvents) ...[
                        _EventRow(event: event),
                        const TableDivider(),
                      ],
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              '${mockEvents.length} eventos · Los datos de check-in se actualizan en tiempo real',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.caption),
            ),
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
  const _EventRow({required this.event});

  final EventItem event;

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
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: event.id)),
              ),
              child: const Text('Ver detalle →'),
            ),
          ),
        ],
      ),
    );
  }
}
