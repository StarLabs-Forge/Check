import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/errors.dart';
import '../../services/superadmin_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/motion.dart';
import '../widgets/proto_ui.dart';

final _svc = SuperadminService.instance;

String _msg(Object e) => e is Exception && e.toString().startsWith('Exception: ') ? e.toString().substring(11) : friendlyError(e);

/// Panel global de la plataforma. No aprueba pagos, no mezcla ingresos de los
/// locales con los de CHECK y no muestra empleados ni compradores (privados
/// de cada local).
class SuperadminExperience extends StatefulWidget {
  const SuperadminExperience({super.key, required this.onExit});
  final VoidCallback onExit;
  @override
  State<SuperadminExperience> createState() => _SuperadminExperienceState();
}

class _SuperadminExperienceState extends State<SuperadminExperience> {
  int _i = 0;

  @override
  void initState() {
    super.initState();
    _svc.load();
  }

  @override
  Widget build(BuildContext context) {
    const items = [
      NavItem('Resumen', Icons.dashboard_outlined),
      NavItem('Locales', Icons.storefront_outlined),
      NavItem('Eventos', Icons.event_outlined),
      NavItem('Auditoría', Icons.fact_check_outlined),
      NavItem('Plataforma', Icons.tune),
    ];
    return AdaptiveShell(
      title: 'Superadministrador',
      subtitle: 'Plataforma CHECK',
      items: items,
      index: _i,
      onSelect: (v) => setState(() => _i = v),
      onExit: widget.onExit,
      body: ListenableBuilder(
        listenable: _svc,
        builder: (context, _) {
          if (_svc.loading && _svc.venues.isEmpty) return const StateView(ViewState.loading);
          if (_svc.error != null && _svc.venues.isEmpty) {
            return StateView(ViewState.error, message: 'No pudimos cargar los datos de la plataforma.', onRetry: _svc.load);
          }
          return switch (_i) {
            0 => const _Overview(),
            1 => const _VenuesPage(),
            2 => const _EventsPage(),
            3 => const _AuditPage(),
            _ => const _PlatformPage(),
          };
        },
      ),
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
    if (data.isEmpty) return Text('Sin datos todavía.', style: ts(AppTextSize.caption, c: AppColors.textSecondary));
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

String _eventStatus(String s) => switch (s) {
      'draft' => 'Borrador',
      'active' => 'Publicado',
      'live' => 'En vivo',
      'finished' => 'Finalizado',
      'suspended' => 'Suspendido',
      _ => s,
    };

Color _eventColor(String s) => switch (s) {
      'live' => AppColors.success,
      'active' => PColors.info,
      'suspended' => AppColors.error,
      _ => AppColors.textSecondary,
    };

Widget _logTile(SaLog a) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(a.label, style: ts(AppTextSize.body, w: FontWeight.w700))),
            Text(fmtDateTime(a.at), style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
          ]),
          if (a.venueName != null) Text(a.venueName!, style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
          if (a.detail != null && a.detail!.isNotEmpty) Text(a.detail!, style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
        ]),
      ),
    );

// ───────────────────────── Resumen ─────────────────────────
class _Overview extends StatelessWidget {
  const _Overview();
  @override
  Widget build(BuildContext context) {
    final v = _svc.venues;
    int sum(int Function(SaVenue) f) => v.fold(0, (s, x) => s + f(x));
    return ResponsiveBody(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H('Resumen de la plataforma', sub: 'Vista global. No muestra ingresos de CHECK ni de los locales.'),
        if (_svc.settings.maintenance)
          const Padding(padding: EdgeInsets.only(bottom: 12), child: Notice('Modo mantenimiento activo: solo los superadministradores pueden entrar.', icon: Icons.construction, color: PColors.warning)),
        _grid([
          _Stat('Locales activos', '${v.where((x) => x.active).length} / ${v.length}', Icons.storefront_outlined),
          _Stat('Eventos', '${sum((x) => x.events)}', Icons.event_outlined),
          _Stat('Eventos activos', '${sum((x) => x.eventsActive)}', Icons.bolt, color: PColors.warning),
          _Stat('Entradas emitidas', '${sum((x) => x.tickets)}', Icons.confirmation_number_outlined, color: PColors.info),
        ]),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 800;
          final a = PCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Pedidos por estado', style: ts(AppTextSize.body, w: FontWeight.w700)),
            const SizedBox(height: 10),
            _Bars([
              ('En verificación', sum((x) => x.order('verifying'))),
              ('Aprobados', sum((x) => x.order('approved'))),
              ('Rechazados', sum((x) => x.order('rejected'))),
              ('Vencidos', sum((x) => x.order('expired'))),
            ]),
            const SizedBox(height: 6),
            Text('El superadministrador no aprueba pagos.', style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
          ]));
          final b = PCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Entradas emitidas por local', style: ts(AppTextSize.body, w: FontWeight.w700)),
            const SizedBox(height: 10),
            _Bars([for (final x in v) (x.name, x.tickets)]),
          ]));
          return wide ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)]) : Column(children: [a, const SizedBox(height: 12), b]);
        }),
        const SizedBox(height: 16),
        PCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Actividad reciente de la plataforma', style: ts(AppTextSize.body, w: FontWeight.w700)),
          const SizedBox(height: 8),
          if (_svc.log.isEmpty) Text('Aún no hay acciones registradas.', style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
          for (final a in _svc.log.take(4)) KV('${fmtDateTime(a.at)} · ${a.label}', a.venueName ?? a.detail ?? ''),
        ])),
        const SizedBox(height: 12),
        const Notice('Los montos de las ventas pertenecen a cada local y se cobran en sus cuentas. Aquí no se muestran como ingresos de CHECK.', icon: Icons.account_balance_outlined, color: PColors.info),
      ]),
    );
  }
}

// ───────────────────────── Locales ─────────────────────────
class _VenuesPage extends StatefulWidget {
  const _VenuesPage();
  @override
  State<_VenuesPage> createState() => _VenuesPageState();
}

class _VenuesPageState extends State<_VenuesPage> {
  String _q = '';
  String _f = 'all';

  Future<void> _create() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const _CreateVenueDialog());
    if (ok == true && mounted) toast(context, 'Local creado');
  }

  @override
  Widget build(BuildContext context) {
    var list = _svc.venues.where((v) => v.name.toLowerCase().contains(_q.toLowerCase())).toList();
    if (_f == 'on') list = list.where((v) => v.active).toList();
    if (_f == 'off') list = list.where((v) => !v.active).toList();
    return ResponsiveBody(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H('Locales registrados'),
        PButton('Nuevo local', icon: Icons.add_business_outlined, onPressed: _create),
        const SizedBox(height: 12),
        TextField(onChanged: (v) => setState(() => _q = v), decoration: const InputDecoration(hintText: 'Buscar local', prefixIcon: Icon(Icons.search))),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [for (final (k, l) in const [('all', 'Todos'), ('on', 'Activos'), ('off', 'Suspendidos')]) ChoiceChip(label: Text(l), selected: _f == k, onSelected: (_) => setState(() => _f = k))]),
        const SizedBox(height: 14),
        if (list.isEmpty) const StateView(ViewState.empty, message: 'Sin resultados.'),
        _grid([
          for (final v in list)
            PCard(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _VenueDetail(v.ownerId))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text(v.name, style: ts(AppTextSize.bodyLg, w: FontWeight.w700))), Chip2(v.active ? 'Activo' : 'Suspendido', v.active ? AppColors.success : AppColors.textSecondary)]),
                const SizedBox(height: 6),
                Text('${v.zone.isEmpty ? 'Sin zona' : v.zone} · Plan ${SuperadminService.planLabel(v.plan)}', style: ts(AppTextSize.body, c: AppColors.textSecondary)),
                Text('${v.events} eventos', style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
              ]),
            ),
        ], minW: 300),
      ]),
    );
  }
}

class _VenueDetail extends StatelessWidget {
  const _VenueDetail(this.ownerId);
  final String ownerId;

  Future<void> _toggle(BuildContext context, SaVenue v) async {
    final suspend = v.active;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: Text(suspend ? 'Suspender ${v.name}' : 'Reactivar ${v.name}'),
        content: Text(suspend
            ? 'El administrador y su personal no podrán iniciar sesión mientras esté suspendido. Esta acción queda registrada.'
            : 'El local volverá a poder iniciar sesión y operar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(suspend ? 'Suspender' : 'Reactivar', style: TextStyle(color: suspend ? AppColors.error : AppColors.accentPrimary))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.setVenueActive(v, !suspend);
      if (context.mounted) toast(context, suspend ? 'Local suspendido' : 'Local reactivado');
    } catch (e) {
      if (context.mounted) toast(context, _msg(e), error: true);
    }
  }

  Future<void> _plan(BuildContext context, SaVenue v, String plan) async {
    try {
      await _svc.setVenuePlan(v, plan);
      if (context.mounted) toast(context, 'Plan actualizado');
    } catch (e) {
      if (context.mounted) toast(context, _msg(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _svc,
      builder: (context, _) {
        final matches = _svc.venues.where((x) => x.ownerId == ownerId);
        if (matches.isEmpty) return Scaffold(appBar: AppBar(), body: const StateView(ViewState.empty, message: 'El local ya no existe.'));
        final v = matches.first;
        final evs = _svc.events.where((e) => e.ownerId == ownerId).toList();
        return Scaffold(
          appBar: AppBar(title: Text(v.name, style: ts(AppTextSize.bodyLg, w: FontWeight.w700))),
          body: ResponsiveBody(
            maxWidth: 800,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              PCard(child: Column(children: [
                KV('Estado', v.active ? 'Activo' : 'Suspendido', vColor: v.active ? AppColors.success : AppColors.error),
                KV('Zona', v.zone.isEmpty ? '—' : v.zone),
                KV('Plan', SuperadminService.planLabel(v.plan)),
                KV('Eventos', '${v.events}'),
                KV('Entradas emitidas', '${v.tickets}'),
                KV('Verificadores de pago', '${v.verifiers}'),
                if (v.lastActivity != null) KV('Última actividad', fmtDateTime(v.lastActivity!)),
              ])),
              const SizedBox(height: 12),
              PCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Plan del local', style: ts(AppTextSize.body, w: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  for (final p in SuperadminService.planNames.keys)
                    ChoiceChip(label: Text(SuperadminService.planLabel(p)), selected: v.plan == p, onSelected: v.plan == p ? null : (_) => _plan(context, v, p)),
                ]),
              ])),
              const SizedBox(height: 12),
              PButton(v.active ? 'Suspender local' : 'Reactivar local', kind: v.active ? BtnKind.danger : BtnKind.primary, onPressed: () => _toggle(context, v)),
              const SizedBox(height: 16),
              Text('Eventos del local', style: ts(AppTextSize.h3, w: FontWeight.w700)),
              const SizedBox(height: 8),
              if (evs.isEmpty) Text('Sin eventos.', style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
              for (final e in evs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PCard(child: Row(children: [
                    Expanded(child: Text(e.name)),
                    Chip2(_eventStatus(e.status), _eventColor(e.status)),
                    const SizedBox(width: 8),
                    Text(fmtDate(e.startsAt), style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
                  ])),
                ),
            ]),
          ),
        );
      },
    );
  }
}

String _genPassword() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
  final r = Random.secure();
  return List.generate(12, (_) => chars[r.nextInt(chars.length)]).join();
}

class _CreateVenueDialog extends StatefulWidget {
  const _CreateVenueDialog();
  @override
  State<_CreateVenueDialog> createState() => _CreateVenueDialogState();
}

class _CreateVenueDialogState extends State<_CreateVenueDialog> {
  final _venue = TextEditingController();
  final _zone = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController(text: _genPassword());
  String _plan = _svc.settings.defaultPlan;
  bool _show = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_venue, _zone, _name, _email, _pass]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    String? err;
    if (_venue.text.trim().isEmpty) err = 'Escribe el nombre del local.';
    if (err == null && _name.text.trim().length < 2) err = 'Escribe el nombre del administrador.';
    if (err == null && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim())) err = 'Correo no válido.';
    if (err == null && (_pass.text.length < 8 || _pass.text.length > 72)) err = 'La contraseña debe tener entre 8 y 72 caracteres.';
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _svc.createVenue(
        venueName: _venue.text.trim(),
        zone: _zone.text.trim(),
        fullName: _name.text.trim(),
        email: _email.text.trim(),
        password: _pass.text,
        plan: _plan,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _msg(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: const Text('Nuevo local'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(controller: _venue, decoration: const InputDecoration(labelText: 'Nombre del local')),
              const SizedBox(height: 10),
              TextField(controller: _zone, decoration: const InputDecoration(labelText: 'Zona (opcional)')),
              const SizedBox(height: 10),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre del administrador')),
              const SizedBox(height: 10),
              TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Correo del administrador')),
              const SizedBox(height: 10),
              TextField(
                controller: _pass,
                obscureText: !_show,
                decoration: InputDecoration(
                  labelText: 'Contraseña inicial',
                  suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(tooltip: 'Mostrar', icon: Icon(_show ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _show = !_show)),
                    IconButton(tooltip: 'Generar', icon: const Icon(Icons.autorenew), onPressed: () => setState(() => _pass.text = _genPassword())),
                    IconButton(tooltip: 'Copiar', icon: const Icon(Icons.copy), onPressed: () => Clipboard.setData(ClipboardData(text: _pass.text))),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                for (final p in SuperadminService.planNames.keys) ChoiceChip(label: Text(SuperadminService.planLabel(p)), selected: _plan == p, onSelected: (_) => setState(() => _plan = p)),
              ]),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: ts(AppTextSize.caption, c: AppColors.error))),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Creando…' : 'Crear local')),
        ],
      );
}

// ───────────────────────── Eventos ─────────────────────────
class _EventsPage extends StatefulWidget {
  const _EventsPage();
  @override
  State<_EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<_EventsPage> {
  String? _venue;
  String? _status;
  @override
  Widget build(BuildContext context) {
    var list = _svc.events.toList();
    if (_venue != null) list = list.where((e) => e.ownerId == _venue).toList();
    if (_status != null) list = list.where((e) => e.status == _status).toList();
    list.sort((a, b) => b.startsAt.compareTo(a.startsAt));
    return ResponsiveBody(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H('Eventos de la plataforma', sub: 'Supervisión global.'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            ChoiceChip(label: const Text('Todos los locales'), selected: _venue == null, onSelected: (_) => setState(() => _venue = null)),
            for (final v in _svc.venues) ...[const SizedBox(width: 8), ChoiceChip(label: Text(v.name), selected: _venue == v.ownerId, onSelected: (_) => setState(() => _venue = v.ownerId))],
          ]),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          ChoiceChip(label: const Text('Cualquier estado'), selected: _status == null, onSelected: (_) => setState(() => _status = null)),
          for (final s in const ['draft', 'active', 'live', 'finished', 'suspended']) ChoiceChip(label: Text(_eventStatus(s)), selected: _status == s, onSelected: (_) => setState(() => _status = s)),
        ]),
        const SizedBox(height: 14),
        if (list.isEmpty) const StateView(ViewState.empty, message: 'Sin eventos con esos filtros.'),
        _grid([
          for (final e in list)
            PCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text(e.name, style: ts(AppTextSize.bodyLg, w: FontWeight.w700))), Chip2(_eventStatus(e.status), _eventColor(e.status))]),
                const SizedBox(height: 4),
                Text('${e.venueName} · ${fmtDate(e.startsAt)}', style: ts(AppTextSize.body, c: AppColors.textSecondary)),
                Text('Capacidad ${e.capacity}', style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
              ]),
            ),
        ], minW: 300),
      ]),
    );
  }
}

// ───────────────────────── Auditoría ─────────────────────────
class _AuditPage extends StatefulWidget {
  const _AuditPage();
  @override
  State<_AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends State<_AuditPage> {
  bool _platform = false;

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
          const Notice('Acciones del equipo CHECK sobre la plataforma: altas, planes, suspensiones y ajustes.', icon: Icons.public, color: PColors.info),
          const SizedBox(height: 12),
          if (_svc.log.isEmpty) const StateView(ViewState.empty, message: 'Aún no hay acciones registradas.'),
          for (final a in _svc.log) _logTile(a),
        ] else ...[
          const Notice('Los datos de empleados y de compradores son privados de cada local y no se muestran aquí.', icon: Icons.lock_outline, color: PColors.info),
          const SizedBox(height: 12),
          if (_svc.audit.isEmpty) const StateView(ViewState.empty, message: 'Aún no hay locales.'),
          _grid([
            for (final a in _svc.audit)
              PCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.venueName, style: ts(AppTextSize.bodyLg, w: FontWeight.w700)),
                  const SizedBox(height: 8),
                  KV('Pagos aprobados / rechazados', '${a.approved} / ${a.rejected}'),
                  KV('Decididos por verificadores', '${a.byVerifiers}'),
                  KV('Bloqueos por doble decisión', '${a.conflicts}'),
                  KV('Cambios de permiso (30 días)', '${a.permissionChanges}'),
                  KV('Última actividad', a.lastActivity == null ? 'Sin actividad' : fmtDateTime(a.lastActivity!)),
                ]),
              ),
          ], minW: 320),
        ],
      ]),
    );
  }
}

// ───────────────────────── Plataforma ─────────────────────────
class _PlatformPage extends StatelessWidget {
  const _PlatformPage();
  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Column(children: [
          const TabBar(tabs: [Tab(text: 'Planes'), Tab(text: 'Usuarios'), Tab(text: 'Ajustes')]),
          const Expanded(child: TabBarView(children: [_PlansTab(), _UsersTab(), _SettingsTab()])),
        ]),
      );
}

class _PlansTab extends StatelessWidget {
  const _PlansTab();

  Future<void> _edit(BuildContext context, SaPlan p) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => _PlanDialog(plan: p));
    if (saved == true && context.mounted) toast(context, 'Plan actualizado');
  }

  @override
  Widget build(BuildContext context) {
    String lim(int? v) => v == null ? 'Ilimitado' : '$v';
    return ResponsiveBody(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H('Planes', sub: 'Límites y precio mensual por plan. «Ilimitado» = sin tope.'),
        _grid([
          for (final p in _svc.plans)
            PCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(SuperadminService.planLabel(p.plan), style: ts(AppTextSize.h3, w: FontWeight.w800))),
                  Chip2('${_svc.venues.where((v) => v.plan == p.plan).length} locales', AppColors.accentPrimary),
                ]),
                const SizedBox(height: 8),
                KV('Precio mensual', 'Bs. ${p.priceBs.toStringAsFixed(p.priceBs == p.priceBs.roundToDouble() ? 0 : 2)}'),
                KV('Eventos por mes', lim(p.maxEvents)),
                KV('Staff por evento', lim(p.maxStaff)),
                KV('Entradas por mes', lim(p.maxTickets)),
                const SizedBox(height: 8),
                PButton('Editar', kind: BtnKind.secondary, icon: Icons.edit_outlined, onPressed: () => _edit(context, p)),
              ]),
            ),
        ], minW: 280),
      ]),
    );
  }
}

class _PlanDialog extends StatefulWidget {
  const _PlanDialog({required this.plan});
  final SaPlan plan;
  @override
  State<_PlanDialog> createState() => _PlanDialogState();
}

class _PlanDialogState extends State<_PlanDialog> {
  late final _events = TextEditingController(text: widget.plan.maxEvents?.toString() ?? '');
  late final _staff = TextEditingController(text: widget.plan.maxStaff?.toString() ?? '');
  late final _tickets = TextEditingController(text: widget.plan.maxTickets?.toString() ?? '');
  late final _price = TextEditingController(text: widget.plan.priceBs.toString());
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_events, _staff, _tickets, _price]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Vacío = ilimitado (null). Devuelve `false` si el texto no es un entero >= 0.
  (bool, int?) _limit(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return (true, null);
    final n = int.tryParse(t);
    return (n != null && n >= 0, n);
  }

  Future<void> _save() async {
    final e = _limit(_events), s = _limit(_staff), t = _limit(_tickets);
    final price = double.tryParse(_price.text.trim().replaceAll(',', '.'));
    if (!e.$1 || !s.$1 || !t.$1 || price == null || price < 0) {
      setState(() => _error = 'Los límites deben ser enteros ≥ 0 (vacío = ilimitado) y el precio un número ≥ 0.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final p = widget.plan;
    final old = (p.maxEvents, p.maxStaff, p.maxTickets, p.priceBs);
    p
      ..maxEvents = e.$2
      ..maxStaff = s.$2
      ..maxTickets = t.$2
      ..priceBs = price;
    try {
      await _svc.savePlan(p);
      if (mounted) Navigator.pop(context, true);
    } catch (err) {
      p
        ..maxEvents = old.$1
        ..maxStaff = old.$2
        ..maxTickets = old.$3
        ..priceBs = old.$4;
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _msg(err);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration d(String l) => InputDecoration(labelText: l, hintText: 'Vacío = ilimitado');
    return AlertDialog(
      backgroundColor: AppColors.bgSurface,
      title: Text('Plan ${SuperadminService.planLabel(widget.plan.plan)}'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: _price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Precio mensual (Bs.)')),
            const SizedBox(height: 10),
            TextField(controller: _events, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: d('Eventos por mes')),
            const SizedBox(height: 10),
            TextField(controller: _staff, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: d('Staff por evento')),
            const SizedBox(height: 10),
            TextField(controller: _tickets, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: d('Entradas por mes')),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: ts(AppTextSize.caption, c: AppColors.error))),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
        TextButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Guardando…' : 'Guardar')),
      ],
    );
  }
}

class _UsersTab extends StatefulWidget {
  const _UsersTab();
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final list = _svc.users.where((u) => u.email.toLowerCase().contains(q) || u.venueName.toLowerCase().contains(q) || u.fullName.toLowerCase().contains(q)).toList();
    return ResponsiveBody(
      maxWidth: 900,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H('Administradores de locales', sub: 'Solo cuentas de administrador. El personal y los compradores son privados de cada local.'),
        TextField(onChanged: (v) => setState(() => _q = v), decoration: const InputDecoration(hintText: 'Buscar por nombre, correo o local', prefixIcon: Icon(Icons.search))),
        const SizedBox(height: 12),
        if (list.isEmpty) const StateView(ViewState.empty, message: 'Sin resultados.'),
        for (final u in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PCard(
              child: Row(children: [
                CircleAvatar(backgroundColor: AppColors.bgBorder, child: Text(u.fullName.isEmpty ? '?' : u.fullName[0].toUpperCase())),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u.fullName.isEmpty ? u.email : u.fullName, style: ts(AppTextSize.body, w: FontWeight.w700)),
                    Text(u.email, style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
                    Text('${u.venueName} · Plan ${SuperadminService.planLabel(u.plan)}${u.lastSignIn == null ? '' : ' · último acceso ${fmtDate(u.lastSignIn!)}'}', style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
                  ]),
                ),
                Chip2(u.active ? 'Activo' : 'Suspendido', u.active ? AppColors.success : AppColors.textSecondary),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _SettingsTab extends StatefulWidget {
  const _SettingsTab();
  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  late bool _reg = _svc.settings.registrationOpen;
  late bool _maint = _svc.settings.maintenance;
  late String _plan = _svc.settings.defaultPlan;
  late final _msgCtrl = TextEditingController(text: _svc.settings.message);
  bool _busy = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await _svc.saveSettings(SaSettings(registrationOpen: _reg, maintenance: _maint, message: _msgCtrl.text.trim(), defaultPlan: _plan));
      if (mounted) toast(context, 'Ajustes guardados');
    } catch (e) {
      if (mounted) toast(context, _msg(e), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBody(
      maxWidth: 700,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H('Configuración de la plataforma'),
        PCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Registro abierto'),
              subtitle: const Text('Si se cierra, las cuentas nuevas creadas por su cuenta quedan suspendidas hasta que las actives. Los locales que das de alta tú no se ven afectados.'),
              value: _reg,
              onChanged: (v) => setState(() => _reg = v),
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Modo mantenimiento'),
              subtitle: const Text('Solo los superadministradores pueden iniciar sesión. Los demás ven el aviso.'),
              value: _maint,
              onChanged: (v) => setState(() => _maint = v),
            ),
            TextField(controller: _msgCtrl, maxLength: 300, maxLines: 2, decoration: const InputDecoration(labelText: 'Mensaje de mantenimiento (opcional)')),
            const Divider(),
            Text('Plan por defecto de cuentas nuevas', style: ts(AppTextSize.body, w: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final p in SuperadminService.planNames.keys) ChoiceChip(label: Text(SuperadminService.planLabel(p)), selected: _plan == p, onSelected: (_) => setState(() => _plan = p)),
            ]),
            const SizedBox(height: 16),
            PButton('Guardar ajustes', loading: _busy, onPressed: _save),
          ]),
        ),
      ]),
    );
  }
}
