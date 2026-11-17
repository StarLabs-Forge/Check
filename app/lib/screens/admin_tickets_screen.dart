import 'package:flutter/material.dart';
import '../data/mock_admin_data.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_scaffold.dart';

/// "Tickets" — implementa el frame "Admin · Tickets" (node 53:383): todos
/// los tickets emitidos en el local, de cualquier evento, con métricas
/// globales (emitidos/pagados/pendientes de pago/ya ingresados) y tabla
/// buscable. Datos mock — sin Supabase todavía; "Exportar CSV" solo simula.
class AdminTicketsScreen extends StatefulWidget {
  const AdminTicketsScreen({super.key});

  @override
  State<AdminTicketsScreen> createState() => _AdminTicketsScreenState();
}

class _AdminTicketsScreenState extends State<AdminTicketsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<GuestItem> get _tickets {
    if (_query.isEmpty) return mockAllTickets;
    return mockAllTickets.where((t) => t.name.toLowerCase().contains(_query.toLowerCase())).toList();
  }

  void _exportCsv() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exportación CSV pendiente de integrar con el backend')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // El Figma trae las métricas globales del local ya calculadas (no
    // derivan del mock de invitados de un solo evento) — se mantienen fijas
    // acá, igual que el resto de datos de esta pantalla, hasta conectar
    // Supabase.
    return AdminScaffold(
      current: AdminRoute.tickets,
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
                      'Tickets',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.h1, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: AppSpacing.s2),
                    Text(
                      'Todos los tickets emitidos en Dharma Club, de cualquier evento',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
                    ),
                  ],
                ),
                SizedBox(
                  width: 220,
                  child: ElevatedButton(onPressed: _exportCsv, child: const Text('Exportar CSV')),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s6),
            Wrap(
              spacing: AppSpacing.s6,
              runSpacing: AppSpacing.s6,
              children: const [
                MetricCard(label: 'Tickets emitidos', value: '650', trendLabel: 'Sin cambios', trendColor: AppColors.accentPrimary, width: 263),
                MetricCard(label: 'Pagados', value: '512', trendLabel: 'Sin cambios', trendColor: AppColors.accentPrimary, width: 263),
                MetricCard(label: 'Pendientes de pago', value: '138', trendLabel: 'Sin cambios', trendColor: AppColors.accentPrimary, width: 263),
                MetricCard(label: 'Ya ingresados', value: '143', trendLabel: 'Sin cambios', trendColor: AppColors.error, width: 263),
              ],
            ),
            const SizedBox(height: AppSpacing.s6),
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
                        'Todos los Tickets',
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
                  const _TicketTableHeader(),
                  const TableDivider(),
                  if (_tickets.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.s6),
                      child: Text(
                        'No se encontraron tickets con ese nombre.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
                      ),
                    )
                  else
                    for (final ticket in _tickets) ...[
                      _TicketRow(ticket: ticket),
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

class _TicketTableHeader extends StatelessWidget {
  const _TicketTableHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.caption, fontWeight: FontWeight.w500);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s3, top: AppSpacing.s3),
      child: Row(
        children: const [
          Expanded(flex: 5, child: Text('Invitado', style: style)),
          Expanded(flex: 3, child: Text('Estado', style: style)),
          Expanded(flex: 2, child: Text('Evento', style: style)),
        ],
      ),
    );
  }
}

class _TicketRow extends StatelessWidget {
  const _TicketRow({required this.ticket});

  final GuestItem ticket;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              ticket.name,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.body, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(flex: 3, child: Align(alignment: Alignment.centerLeft, child: StatusBadge(ticket.status))),
          Expanded(
            flex: 2,
            child: Text(ticket.eventName, style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body)),
          ),
        ],
      ),
    );
  }
}
