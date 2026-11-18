import 'package:flutter/material.dart';
import '../../widgets/motion.dart';

import '../../theme/app_theme.dart';
import '../admin/admin_flow.dart' show AuditTile;
import '../data/proto_store.dart';
import '../widgets/proto_ui.dart';

final _store = ProtoStore.instance;

/// Panel global de la plataforma (solo lectura / supervisión).
/// No aprueba pagos ni mezcla ingresos de los locales con los de CHECK.
class SuperadminExperience extends StatefulWidget {
  const SuperadminExperience({super.key, required this.onExit});
  final VoidCallback onExit;
  @override
  State<SuperadminExperience> createState() => _SuperadminExperienceState();
}

class _SuperadminExperienceState extends State<SuperadminExperience> {
  int _i = 0;
  @override
  Widget build(BuildContext context) {
    const items = [
      NavItem('Resumen', Icons.dashboard_outlined),
      NavItem('Locales', Icons.storefront_outlined),
      NavItem('Eventos', Icons.event_outlined),
      NavItem('Actividad', Icons.insights_outlined),
      NavItem('Auditoría', Icons.fact_check_outlined),
    ];
    final body = switch (_i) {
      0 => const _Overview(),
      1 => const _VenuesPage(),
      2 => const _EventsPage(),
      3 => const _ActivityPage(),
      _ => const _GlobalAudit(),
    };
    return AdaptiveShell(
      title: 'Superadministrador',
      subtitle: 'Plataforma CHECK',
      items: items,
      index: _i,
      onSelect: (v) => setState(() => _i = v),
      onExit: widget.onExit,
      body: ListenableBuilder(listenable: _store, builder: (_, _) => body),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.icon, {this.color = AppColors.accentPrimary});
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => PCard(
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.md)), child: Icon(icon, color: color)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
            AnimatedCount(value, style: ts(AppTextSize.h2, w: FontWeight.w800)),
          ])),
        ]),
      );
}

Widget _grid(List<Widget> kids, {int minW = 240}) => LayoutBuilder(builder: (context, c) {
      final cols = (c.maxWidth / minW).floor().clamp(1, 4);
      final w = (c.maxWidth - (cols - 1) * 12) / cols;
      return Wrap(spacing: 12, runSpacing: 12, children: [for (final k in kids) SizedBox(width: w, child: k)]);
    });

class _Bars extends StatelessWidget {
  const _Bars(this.data);
  final List<(String, int)> data;
  @override
  Widget build(BuildContext context) {
    final mx = data.fold<int>(1, (m, d) => d.$2 > m ? d.$2 : m);
    return Column(children: [
      for (final d in data)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            SizedBox(width: 110, child: Text(d.$1, overflow: TextOverflow.ellipsis, style: ts(AppTextSize.caption, c: AppColors.textSecondary))),
            Expanded(
              child: LayoutBuilder(builder: (context, c) => Stack(children: [
                Container(height: 10, decoration: BoxDecoration(color: AppColors.bgBorder, borderRadius: BorderRadius.circular(5))),
                TweenAnimationBuilder<double>(
                  tween: Tween(end: d.$2 / mx),
                  duration: Motion.reduced(context) ? Duration.zero : const Duration(milliseconds: 700),
                  curve: Motion.enter,
                  builder: (context, v, _) => Container(height: 10, width: c.maxWidth * v, decoration: BoxDecoration(color: AppColors.accentPrimary, borderRadius: BorderRadius.circular(5))),
                ),
              ])),
            ),
            SizedBox(width: 36, child: Text('${d.$2}', textAlign: TextAlign.right, style: ts(AppTextSize.caption, w: FontWeight.w700))),
          ]),
        ),
    ]);
  }
}

// C1
class _Overview extends StatelessWidget {
  const _Overview();
  @override
  Widget build(BuildContext context) {
    final active = _store.events.where((e) => e.state == EventState.active).length;
    final upcoming = _store.events.where((e) => e.state == EventState.upcoming).length;
    final sold = _store.events.fold(0, (s, e) => s + _store.ticketsSold(e.id));
    final week = const [('Lun', 4), ('Mar', 7), ('Mié', 5), ('Jue', 11), ('Vie', 19), ('Sáb', 26), ('Dom', 9)];
    return ResponsiveBody(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H('Resumen de la plataforma', sub: 'Vista global. No muestra ingresos de CHECK ni de los locales.'),
        _grid([
          _Stat('Locales', '${_store.venues.where((v) => v.active).length} / ${_store.venues.length}', Icons.storefront_outlined),
          _Stat('Eventos', '${_store.events.length}', Icons.event_outlined),
          _Stat('Activos / próximos', '$active / $upcoming', Icons.bolt, color: PColors.warning),
          _Stat('Entradas vendidas', '$sold', Icons.confirmation_number_outlined, color: PColors.info),
        ]),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 800;
          final a = PCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Pedidos creados por día (demo)', style: ts(AppTextSize.body, w: FontWeight.w700)),
            const SizedBox(height: 10),
            _Bars(week),
          ]));
          final b = PCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Entradas vendidas por evento', style: ts(AppTextSize.body, w: FontWeight.w700)),
            const SizedBox(height: 10),
            _Bars([for (final e in _store.events) (e.name, _store.ticketsSold(e.id))]),
          ]));
          return wide ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)]) : Column(children: [a, const SizedBox(height: 12), b]);
        }),
        const SizedBox(height: 16),
        PCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Actividad reciente', style: ts(AppTextSize.body, w: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final a in _store.platformLog.take(3)) KV('${fmtDateTime(a.at)} · ${a.action}', a.result),
        ])),
      ]),
    );
  }
}

// C2
class _VenuesPage extends StatefulWidget {
  const _VenuesPage();
  @override
  State<_VenuesPage> createState() => _VenuesPageState();
}

class _VenuesPageState extends State<_VenuesPage> {
  String _q = '';
  String _f = 'all';
  @override
  Widget build(BuildContext context) {
    var list = _store.venues.where((v) => v.name.toLowerCase().contains(_q.toLowerCase())).toList();
    if (_f == 'on') list = list.where((v) => v.active).toList();
    if (_f == 'off') list = list.where((v) => !v.active).toList();
    return ResponsiveBody(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H('Locales registrados'),
        TextField(onChanged: (v) => setState(() => _q = v), decoration: const InputDecoration(hintText: 'Buscar local', prefixIcon: Icon(Icons.search))),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [for (final (k, l) in const [('all', 'Todos'), ('on', 'Activos'), ('off', 'Inactivos')]) ChoiceChip(label: Text(l), selected: _f == k, onSelected: (_) => setState(() => _f = k))]),
        const SizedBox(height: 14),
        if (list.isEmpty) const StateView(ViewState.empty, message: 'Sin resultados.'),
        _grid([
          for (final v in list)
            PCard(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _VenueDetail(v.id))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text(v.name, style: ts(AppTextSize.bodyLg, w: FontWeight.w700))), Chip2(v.active ? 'Activo' : 'Inactivo', v.active ? AppColors.success : AppColors.textSecondary)]),
                const SizedBox(height: 6),
                Text('${v.zone} · Plan ${v.plan}', style: ts(AppTextSize.body, c: AppColors.textSecondary)),
                Text('${_store.events.where((e) => e.venueId == v.id).length} eventos', style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
              ]),
            ),
        ], minW: 300),
      ]),
    );
  }
}

class _VenueDetail extends StatelessWidget {
  const _VenueDetail(this.id);
  final String id;
  @override
  Widget build(BuildContext context) {
    final v = _store.venueById(id);
    final evs = _store.events.where((e) => e.venueId == id).toList();
    return Scaffold(
      appBar: AppBar(title: Text(v.name, style: ts(AppTextSize.bodyLg, w: FontWeight.w700))),
      body: ResponsiveBody(
        maxWidth: 800,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PCard(child: Column(children: [
            KV('Estado', v.active ? 'Activo' : 'Inactivo', vColor: v.active ? AppColors.success : AppColors.textSecondary),
            KV('Zona', v.zone),
            KV('Plan', v.plan),
            KV('Eventos', '${evs.length}'),
            KV('Entradas vendidas', '${evs.fold(0, (s, e) => s + _store.ticketsSold(e.id))}'),
          ])),
          const SizedBox(height: 12),
          const Notice('Vista de supervisión. Las suspensiones reales y su alcance están pendientes de definición funcional; no hay acciones destructivas en el prototipo.'),
          const SizedBox(height: 12),
          Text('Eventos del local', style: ts(AppTextSize.h3, w: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final e in evs)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: PCard(child: Row(children: [Expanded(child: Text(e.name)), Text(fmtDate(e.date), style: ts(AppTextSize.caption, c: AppColors.textSecondary))]))),
        ]),
      ),
    );
  }
}

// C3
class _EventsPage extends StatefulWidget {
  const _EventsPage();
  @override
  State<_EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<_EventsPage> {
  String? _venue;
  EventState? _state;
  @override
  Widget build(BuildContext context) {
    var list = _store.events.toList();
    if (_venue != null) list = list.where((e) => e.venueId == _venue).toList();
    if (_state != null) list = list.where((e) => e.state == _state).toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    String sl(EventState s) => switch (s) { EventState.active => 'Activo', EventState.upcoming => 'Próximo', EventState.finished => 'Finalizado' };
    return ResponsiveBody(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H('Eventos de la plataforma', sub: 'Supervisión global.'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            ChoiceChip(label: const Text('Todos los locales'), selected: _venue == null, onSelected: (_) => setState(() => _venue = null)),
            for (final v in _store.venues) ...[const SizedBox(width: 8), ChoiceChip(label: Text(v.name), selected: _venue == v.id, onSelected: (_) => setState(() => _venue = v.id))],
          ]),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          ChoiceChip(label: const Text('Cualquier estado'), selected: _state == null, onSelected: (_) => setState(() => _state = null)),
          for (final s in EventState.values) ChoiceChip(label: Text(sl(s)), selected: _state == s, onSelected: (_) => setState(() => _state = s)),
        ]),
        const SizedBox(height: 14),
        if (list.isEmpty) const StateView(ViewState.empty, message: 'Sin eventos con esos filtros.'),
        _grid([
          for (final e in list)
            PCard(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _EventDetail(e.id))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text(e.name, style: ts(AppTextSize.bodyLg, w: FontWeight.w700))), Chip2(sl(e.state), e.state == EventState.active ? AppColors.success : e.state == EventState.upcoming ? PColors.info : AppColors.textSecondary)]),
                const SizedBox(height: 4),
                Text('${_store.venueById(e.venueId).name} · ${fmtDate(e.date)}', style: ts(AppTextSize.body, c: AppColors.textSecondary)),
                Text('${_store.ticketsSold(e.id)} entradas vendidas', style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
              ]),
            ),
        ], minW: 300),
      ]),
    );
  }
}

class _EventDetail extends StatelessWidget {
  const _EventDetail(this.id);
  final String id;
  @override
  Widget build(BuildContext context) {
    final e = _store.eventById(id);
    final orders = _store.orders.where((o) => o.eventId == id).toList();
    int c(OrderStatus s) => orders.where((o) => o.status == s).length;
    return Scaffold(
      appBar: AppBar(title: Text(e.name, style: ts(AppTextSize.bodyLg, w: FontWeight.w700))),
      body: ResponsiveBody(
        maxWidth: 800,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Cover(e.hue, height: 130),
          const SizedBox(height: 12),
          PCard(child: Column(children: [
            KV('Local', _store.venueById(e.venueId).name),
            KV('Fecha', fmtDateTime(e.date)),
            KV('Capacidad en venta', '${e.totalCapacity}'),
            KV('Entradas vendidas', '${_store.ticketsSold(e.id)}'),
          ])),
          const SizedBox(height: 12),
          PCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Pedidos por estado', style: ts(AppTextSize.body, w: FontWeight.w700)),
            KV('En verificación', '${c(OrderStatus.verifying)}'),
            KV('Aprobados', '${c(OrderStatus.approved)}'),
            KV('Rechazados', '${c(OrderStatus.rejected)}'),
          ])),
        ]),
      ),
    );
  }
}

// C4
class _ActivityPage extends StatelessWidget {
  const _ActivityPage();
  @override
  Widget build(BuildContext context) {
    int c(OrderStatus s) => _store.orders.where((o) => o.status == s).length;
    return ResponsiveBody(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H('Actividad y pagos', sub: 'Indicadores de volumen. El superadministrador no aprueba pagos.'),
        _grid([
          _Stat('Pedidos totales', '${_store.orders.length}', Icons.receipt_long_outlined),
          _Stat('En verificación', '${c(OrderStatus.verifying)}', Icons.hourglass_bottom, color: PColors.warning),
          _Stat('Aprobados', '${c(OrderStatus.approved)}', Icons.check_circle_outline, color: AppColors.success),
          _Stat('Rechazados', '${c(OrderStatus.rejected)}', Icons.block, color: AppColors.error),
        ], minW: 220),
        const SizedBox(height: 16),
        PCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Pedidos por local', style: ts(AppTextSize.body, w: FontWeight.w700)),
          const SizedBox(height: 10),
          _Bars([for (final v in _store.venues) (v.name, _store.orders.where((o) => _store.eventById(o.eventId).venueId == v.id).length)]),
        ])),
        const SizedBox(height: 12),
        const Notice('Los montos de las ventas pertenecen a cada local y se cobran en sus cuentas. Aquí no se muestran como ingresos de CHECK; los ingresos de la plataforma (suscripciones) están fuera de este prototipo.', icon: Icons.account_balance_outlined, color: PColors.info),
      ]),
    );
  }
}

// C5 · Auditoría global: primero una vista general por local; al entrar a uno se
// ve su actividad SIN datos de empleados ni de compradores (son privados del local).
String _venueOf(AuditEntry a) {
  if (a.venue != null) return a.venue!;
  if (a.orderNumber != null) {
    for (final o in _store.orders) {
      if (o.number == a.orderNumber) return _store.venueById(_store.eventById(o.eventId).venueId).name;
    }
  }
  return 'Dharma Club';
}

String _roleOf(AuditEntry a) {
  if (a.permission.contains('Verificador')) return 'Verificador delegado';
  if (a.permission.contains('Administrador')) return 'Administrador del local';
  return a.permission;
}

String _kindOf(AuditEntry a) {
  if (a.action.contains('Aprobó')) return 'Pago aprobado';
  if (a.action.contains('Rechazó')) return 'Pago rechazado';
  if (a.action.contains('bloqueado')) return 'Decisión duplicada bloqueada';
  if (a.action.contains('Revocó')) return 'Permiso de verificación revocado';
  if (a.action.contains('permiso')) return 'Permiso de verificación concedido';
  return a.action;
}

class _GlobalAudit extends StatefulWidget {
  const _GlobalAudit();
  @override
  State<_GlobalAudit> createState() => _GlobalAuditState();
}

class _GlobalAuditState extends State<_GlobalAudit> {
  bool _platform = false;

  List<AuditEntry> _of(String venue) =>
      [..._store.audit, ..._store.platformLog].where((a) => _venueOf(a) == venue).toList()..sort((a, b) => b.at.compareTo(a.at));

  @override
  Widget build(BuildContext context) {
    return ResponsiveBody(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H('Auditoría global', sub: 'Vista general por local. Solo lectura.'),
        Wrap(spacing: 8, children: [
          ChoiceChip(label: const Text('Por local'), selected: !_platform, onSelected: (_) => setState(() => _platform = false)),
          ChoiceChip(label: const Text('Plataforma'), selected: _platform, onSelected: (_) => setState(() => _platform = true)),
        ]),
        const SizedBox(height: 14),
        if (_platform) ...[
          const Notice('Acciones del equipo CHECK sobre la plataforma: altas, planes, suspensiones y publicaciones.', icon: Icons.public, color: PColors.info),
          const SizedBox(height: 12),
          for (final a in _store.platformLog) AuditTile(a),
        ] else ...[
          const Notice('Los datos de empleados y de compradores son privados de cada local y no se muestran aquí.', icon: Icons.lock_outline, color: PColors.info),
          const SizedBox(height: 12),
          _grid([
            for (final v in _store.venues)
              Builder(builder: (context) {
                final list = _of(v.name);
                int c(bool Function(AuditEntry) t) => list.where(t).length;
                final last = list.isEmpty ? null : list.first.at;
                return PCard(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _VenueAudit(v.name))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(v.name, style: ts(AppTextSize.bodyLg, w: FontWeight.w700))),
                      Chip2(v.active ? 'Activo' : 'Inactivo', v.active ? AppColors.success : AppColors.textSecondary),
                    ]),
                    const SizedBox(height: 4),
                    Text('${v.zone} · Plan ${v.plan}', style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
                    const SizedBox(height: 10),
                    KV('Acciones registradas', '${list.length}'),
                    KV('Pagos aprobados / rechazados', '${c((a) => a.action.contains('Aprobó'))} / ${c((a) => a.action.contains('Rechazó'))}'),
                    KV('Bloqueos por doble decisión', '${c((a) => a.action.contains('bloqueado'))}'),
                    KV('Última actividad', last == null ? 'Sin actividad' : fmtDateTime(last)),
                  ]),
                );
              }),
          ], minW: 320),
        ],
      ]),
    );
  }
}

class _VenueAudit extends StatelessWidget {
  const _VenueAudit(this.venue);
  final String venue;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final list = [..._store.audit, ..._store.platformLog].where((a) => _venueOf(a) == venue).toList()
          ..sort((a, b) => b.at.compareTo(a.at));
        int c(bool Function(AuditEntry) t) => list.where(t).length;
        return Scaffold(
          appBar: AppBar(title: Text('Auditoría · $venue', style: ts(AppTextSize.bodyLg, w: FontWeight.w700))),
          body: ResponsiveBody(
            maxWidth: 800,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Notice('Actividad del local sin identidad de empleados, motivos ni datos de compradores. Solo lectura.', icon: Icons.lock_outline, color: PColors.info),
              const SizedBox(height: 12),
              _grid([
                _Stat('Aprobados', '${c((a) => a.action.contains('Aprobó'))}', Icons.check_circle_outline, color: AppColors.success),
                _Stat('Rechazados', '${c((a) => a.action.contains('Rechazó'))}', Icons.block, color: AppColors.error),
                _Stat('Bloqueos', '${c((a) => a.action.contains('bloqueado'))}', Icons.sync_problem, color: PColors.warning),
                _Stat('Cambios de permiso', '${c((a) => a.action.contains('permiso'))}', Icons.verified_user_outlined, color: PColors.info),
              ], minW: 170),
              const SizedBox(height: 16),
              if (list.isEmpty) const StateView(ViewState.empty, message: 'Este local aún no tiene actividad.'),
              for (final a in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(_kindOf(a), style: ts(AppTextSize.body, w: FontWeight.w700))),
                        Text(fmtDateTime(a.at), style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
                      ]),
                      const SizedBox(height: 6),
                      KV('Rol', _roleOf(a)),
                      if (a.orderNumber != null) KV('Orden', a.orderNumber!),
                      KV('Resultado', a.result),
                    ]),
                  ),
                ),
            ]),
          ),
        );
      },
    );
  }
}
