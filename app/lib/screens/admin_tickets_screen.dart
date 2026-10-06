import 'dart:async';

import 'package:flutter/material.dart';

import '../data/admin_repository.dart';
import '../data/models.dart';
import '../services/app_session.dart';
import '../services/errors.dart';
import '../services/table_watcher.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_scaffold.dart';
import '../widgets/async_states.dart';

/// "Tickets" — todos los tickets emitidos en el local, de cualquier evento,
/// con métricas globales (emitidos/pagados/pendientes de pago/ya ingresados)
/// y tabla buscable. Datos reales de Supabase; el buscador filtra en el
/// servidor (con debounce) y la pantalla se refresca en vivo.
class AdminTicketsScreen extends StatefulWidget {
  const AdminTicketsScreen({super.key});

  @override
  State<AdminTicketsScreen> createState() => _AdminTicketsScreenState();
}

class _AdminTicketsScreenState extends State<AdminTicketsScreen> {
  static const _pageLimit = 500;

  final _repo = AdminRepository.instance;
  final _searchCtrl = TextEditingController();
  late final TableWatcher _watcher;
  Timer? _searchDebounce;

  String _query = '';
  bool _loading = true;
  String? _error;
  List<EventItem> _events = const [];
  List<GuestItem> _tickets = const [];

  @override
  void initState() {
    super.initState();
    _load();
    _watcher = TableWatcher(tables: const ['tickets', 'events'], onChange: _load)..start();
  }

  @override
  void dispose() {
    _watcher.dispose();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final queryAtStart = _query;
    try {
      final results = await Future.wait([
        _repo.listEvents(),
        _repo.listTickets(query: queryAtStart, limit: _pageLimit),
      ]);
      if (!mounted) return;
      // Si el usuario siguió escribiendo mientras cargaba, descarta esta
      // respuesta (ya hay otra consulta en camino).
      if (queryAtStart != _query) return;
      setState(() {
        _events = results[0] as List<EventItem>;
        _tickets = results[1] as List<GuestItem>;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_tickets.isEmpty && _events.isEmpty) _error = friendlyError(e);
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

  void _onSearchChanged(String value) {
    _query = value.trim();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), _load);
  }

  void _exportCsv() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('La exportación CSV llega en una próxima versión')),
    );
  }

  int _sum(int Function(EventItem e) pick) => _events.fold(0, (acc, e) => acc + pick(e));

  @override
  Widget build(BuildContext context) {
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
                  children: [
                    const Text(
                      'Tickets',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.h1, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    ValueListenableBuilder<Profile?>(
                      valueListenable: AppSession.profile,
                      builder: (_, profile, _) => Text(
                        'Todos los tickets emitidos en ${profile?.venueName ?? ''}, de cualquier evento',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
                      ),
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
            if (_loading)
              const LoadingBlock()
            else if (_error != null)
              ErrorBlock(message: _error!, onRetry: _retry)
            else ...[
              Wrap(
                spacing: AppSpacing.s6,
                runSpacing: AppSpacing.s6,
                children: [
                  MetricCard(
                    label: 'Tickets emitidos',
                    value: '${_sum((e) => e.ticketsTotal)}',
                    trendLabel: 'Sin cancelados',
                    width: 263,
                  ),
                  MetricCard(
                    label: 'Pagados',
                    value: '${_sum((e) => e.ticketsPaid)}',
                    trendLabel: 'Pago confirmado',
                    trendColor: AppColors.accentPrimary,
                    width: 263,
                  ),
                  MetricCard(
                    label: 'Pendientes de pago',
                    value: '${_sum((e) => e.ticketsPendingPayment)}',
                    trendLabel: 'Se cobran en puerta',
                    width: 263,
                  ),
                  MetricCard(
                    label: 'Ya ingresados',
                    value: '${_sum((e) => e.checkins)}',
                    trendLabel: 'Check-ins totales',
                    trendColor: AppColors.accentPrimary,
                    width: 263,
                  ),
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
                          onChanged: _onSearchChanged,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    const _TicketTableHeader(),
                    const TableDivider(),
                    if (_tickets.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
                        child: Text(
                          _query.isEmpty
                              ? 'Aún no hay tickets emitidos.'
                              : 'No se encontraron tickets con ese nombre.',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
                        ),
                      )
                    else
                      for (final ticket in _tickets) ...[
                        _TicketRow(ticket: ticket),
                        const TableDivider(),
                      ],
                    if (_tickets.length >= _pageLimit)
                      const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.s4),
                        child: Text(
                          'Mostrando los 500 más recientes. Usa el buscador para acotar.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.caption),
                        ),
                      ),
                  ],
                ),
              ),
            ],
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
