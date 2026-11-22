import 'dart:math';

import 'package:flutter/material.dart';
import '../../widgets/motion.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../theme/app_theme.dart';
import '../data/proto_store.dart';
import '../widgets/proto_ui.dart';

final _store = ProtoStore.instance;

/// Panel del local. Sirve para el administrador (todo) y para el verificador
/// delegado (solo pagos + su historial). Responsive: móvil y web.
class AdminExperience extends StatefulWidget {
  const AdminExperience({super.key, required this.role, required this.onExit});
  final ProtoRole role; // admin | verifier
  final VoidCallback onExit;
  @override
  State<AdminExperience> createState() => _AdminExperienceState();
}

class _AdminExperienceState extends State<AdminExperience> {
  int _i = 0;

  bool get _isAdmin => widget.role == ProtoRole.admin;
  Actor get _actor => _isAdmin ? ProtoStore.admin : ProtoStore.verifierActor;

  bool get _allowed => _isAdmin || _store.verifierEnabled(ProtoStore.verifierActor.id);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final items = _isAdmin
            ? [
                NavItem('Pagos', Icons.payments_outlined, badge: _store.pending.length),
                NavItem('Avisos', Icons.notifications_outlined, badge: _store.unreadNotifications),
                const NavItem('Delegación', Icons.verified_user_outlined),
                const NavItem('Historial', Icons.history),
              ]
            : [
                NavItem('Pagos', Icons.payments_outlined, badge: _allowed ? _store.pending.length : 0),
                const NavItem('Historial', Icons.history),
              ];
        if (_i >= items.length) _i = 0;

        Widget body;
        if (!_allowed) {
          body = Center(
            child: StateView(
              ViewState.denied,
              message: 'El administrador revocó tu permiso de verificación de pagos. Ya no puedes ver ni resolver solicitudes.',
              onRetry: () => setState(() {}),
            ),
          );
        } else {
          final key = items[_i].label;
          body = switch (key) {
            'Pagos' => PaymentsInbox(actor: _actor),
            'Avisos' => NotificationsPage(actor: _actor, goToPayments: () => setState(() => _i = 0)),
            'Delegación' => const DelegationPage(),
            _ => HistoryPage(actor: _actor, onlyMine: !_isAdmin),
          };
        }

        return AdaptiveShell(
          title: _isAdmin ? 'Dharma Club · Admin' : 'Verificador delegado',
          subtitle: _actor.name,
          items: items,
          index: _i,
          onSelect: (v) => setState(() => _i = v),
          onExit: widget.onExit,
          body: body,
        );
      },
    );
  }
}

// ───────────────────────── Bandeja ─────────────────────────
class PaymentsInbox extends StatefulWidget {
  const PaymentsInbox({super.key, required this.actor});
  final Actor actor;
  @override
  State<PaymentsInbox> createState() => _PaymentsInboxState();
}

class _PaymentsInboxState extends State<PaymentsInbox> {
  bool _loading = true;
  bool _error = false;
  String? _event;
  String _age = 'all'; // all | lt15 | lt60 | gt60
  String _amount = 'all'; // all | lt100 | gte100
  OrderStatus? _status = OrderStatus.verifying;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool fail = false}) async {
    setState(() {
      _loading = true;
      _error = false;
    });
    if (_store.live) {
      await _store.loadAdmin();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _store.adminError != null;
      });
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = fail;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBody(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: H('Pagos por verificar', sub: 'Comprueba cada depósito en la cuenta bancaria del local.')),
          if (_store.live)
            IconButton(tooltip: 'Actualizar', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))
          else
            PopupMenuButton<String>(
              tooltip: 'Opciones de demo',
              onSelected: (v) => v == 'err' ? _load(fail: true) : _load(),
              itemBuilder: (_) => const [PopupMenuItem(value: 'ref', child: Text('Actualizar')), PopupMenuItem(value: 'err', child: Text('Simular error de carga'))],
            ),
        ]),
        if (_loading)
          const StateView(ViewState.loading)
        else if (_error)
          StateView(ViewState.error, message: 'No pudimos cargar las solicitudes.', onRetry: _load)
        else
          ListenableBuilder(listenable: _store, builder: (_, _) => _content()),
      ]),
    );
  }

  Widget _content() {
    var list = _store.orders.where((o) => o.status != OrderStatus.awaitingPayment && o.status != OrderStatus.cancelled && o.status != OrderStatus.expired).toList();
    if (_status != null) list = list.where((o) => o.status == _status).toList();
    if (_event != null) list = list.where((o) => o.eventId == _event).toList();
    list = list.where((o) {
      final m = DateTime.now().difference(o.declaredAt ?? o.createdAt).inMinutes;
      return switch (_age) { 'lt15' => m < 15, 'lt60' => m < 60, 'gt60' => m >= 60, _ => true };
    }).where((o) => switch (_amount) { 'lt100' => o.total < 100, 'gte100' => o.total >= 100, _ => true }).toList();
    list.sort((a, b) => (a.declaredAt ?? a.createdAt).compareTo(b.declaredAt ?? b.createdAt));

    final pend = _store.pending;
    final oldest = pend.isEmpty ? null : pend.first.declaredAt!;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 600 ? 3 : 1;
        final w = (c.maxWidth - (cols - 1) * 12) / cols;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(width: w, child: _Metric('Pendientes', '${pend.length}', PColors.warning, Icons.hourglass_bottom)),
          SizedBox(width: w, child: _Metric('Más antigua', oldest == null ? '—' : waitText(oldest), oldest == null ? AppColors.textSecondary : ageColor(oldest), Icons.schedule)),
          SizedBox(width: w, child: _Metric('Monto pendiente', money(pend.fold(0.0, (s, o) => s + o.total)), AppColors.accentPrimary, Icons.account_balance_wallet_outlined)),
        ]);
      }),
      const SizedBox(height: 16),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _drop<OrderStatus?>('Estado', _status, {null: 'Todos', OrderStatus.verifying: 'Pendientes', OrderStatus.approved: 'Aprobados', OrderStatus.rejected: 'Rechazados'}, (v) => setState(() => _status = v)),
          const SizedBox(width: 8),
          _drop<String?>('Evento', _event, {null: 'Todos', for (final e in _store.events) e.id: e.name}, (v) => setState(() => _event = v)),
          const SizedBox(width: 8),
          _drop<String>('Antigüedad', _age, const {'all': 'Cualquiera', 'lt15': '< 15 min', 'lt60': '< 1 h', 'gt60': '> 1 h'}, (v) => setState(() => _age = v!)),
          const SizedBox(width: 8),
          _drop<String>('Importe', _amount, const {'all': 'Cualquiera', 'lt100': '< Bs. 100', 'gte100': '≥ Bs. 100'}, (v) => setState(() => _amount = v!)),
        ]),
      ),
      const SizedBox(height: 16),
      if (list.isEmpty)
        const StateView(ViewState.empty, message: 'No hay solicitudes con estos filtros.')
      else
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 900 ? 2 : 1;
          final w = (c.maxWidth - (cols - 1) * 12) / cols;
          return Wrap(spacing: 12, runSpacing: 12, children: [for (final o in list) SizedBox(width: w, child: _PaymentCard(o, widget.actor))]);
        }),
    ]);
  }

  Widget _drop<T>(String label, T value, Map<T, String> opts, ValueChanged<T?> onChanged) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: AppColors.bgInput, borderRadius: BorderRadius.circular(AppRadius.full), border: Border.all(color: AppColors.bgBorder)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            dropdownColor: AppColors.bgSurface,
            style: ts(AppTextSize.body),
            hint: Text(label),
            items: [for (final en in opts.entries) DropdownMenuItem<T>(value: en.key, child: Text('$label: ${en.value}'))],
            onChanged: onChanged,
          ),
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.color, this.icon);
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) => PCard(
        child: Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
            AnimatedCount(value, style: ts(AppTextSize.h2, w: FontWeight.w800, c: color)),
          ])),
        ]),
      );
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard(this.o, this.actor);
  final Order o;
  final Actor actor;
  @override
  Widget build(BuildContext context) {
    final e = _store.eventById(o.eventId);
    final since = o.declaredAt ?? o.createdAt;
    final pending = o.status == OrderStatus.verifying;
    return PCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PaymentDetailScreen(o.id, actor))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(o.number, style: ts(AppTextSize.bodyLg, w: FontWeight.w700))),
          Chip2(statusLabel(o.status), statusColor(o.status)),
        ]),
        const SizedBox(height: 6),
        Text(o.buyerName, style: ts(AppTextSize.bodyLg)),
        Text('${e.name} · ${o.ticketCount} ${o.ticketCount == 1 ? 'entrada' : 'entradas'}', style: ts(AppTextSize.body, c: AppColors.textSecondary)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Text(money(o.total), style: ts(AppTextSize.h3, w: FontWeight.w800, c: AppColors.accentPrimary))),
          if (pending) ...[
            Icon(Icons.schedule, size: 14, color: ageColor(since)),
            const SizedBox(width: 4),
            Text('Espera ${waitText(since)}', style: ts(AppTextSize.caption, w: FontWeight.w600, c: ageColor(since))),
          ] else
            Text(fmtDateTime(since), style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
        ]),
        if (pending) ...[
          const SizedBox(height: 10),
          Text('Declarado ${fmtDateTime(since)}', style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
          const SizedBox(height: 10),
          PButton('Revisar pago', icon: Icons.fact_check_outlined, onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PaymentDetailScreen(o.id, actor)))),
        ],
      ]),
    );
  }
}

// ───────────────────────── Detalle / verificación ─────────────────────────
class PaymentDetailScreen extends StatefulWidget {
  const PaymentDetailScreen(this.orderId, this.actor, {super.key});
  final String orderId;
  final Actor actor;
  @override
  State<PaymentDetailScreen> createState() => _PaymentDetailState();
}

class _PaymentDetailState extends State<PaymentDetailScreen> {
  bool _busy = false;
  bool _conflict = false;
  // Estado que esta pantalla «conoce»: si otro usuario decide mientras tanto,
  // los botones siguen visibles hasta actualizar y el intento queda bloqueado.
  late OrderStatus _seen = _store.orderById(widget.orderId)!.status;

  bool get _allowed => widget.actor.id == ProtoStore.admin.id || _store.verifierEnabled(widget.actor.id);

  Future<void> _approve() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: const Text('¿Aprobar este pago?'),
        content: Text('Confirma que ya viste el depósito de ${money(_store.orderById(widget.orderId)!.total)} en la cuenta bancaria del local. Se generará un QR individual por entrada.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Aún no')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sí, aprobar', style: TextStyle(color: AppColors.accentPrimary))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _decide(() => _store.approve(widget.orderId, widget.actor), _store.live ? 'Pago aprobado · QR generados' : 'Pago aprobado · QR generados (simulado)');
  }

  Future<void> _reject() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.modal))),
      builder: (_) => const _RejectSheet(),
    );
    if (reason == null || !mounted) return;
    await _decide(() => _store.reject(widget.orderId, widget.actor, reason), _store.live ? 'Pago rechazado definitivamente · cupos liberados' : 'Pago rechazado definitivamente · cupos liberados (simulado)');
  }

  Future<void> _decide(Future<DecisionResult> Function() action, String okMsg) async {
    if (!_allowed) {
      toast(context, 'Tu permiso fue revocado. No puedes decidir.', error: true);
      return;
    }
    setState(() => _busy = true);
    if (!_store.live) await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final DecisionResult r;
    try {
      r = await action();
    } on StoreException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      toast(context, e.message, error: true);
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _conflict = r == DecisionResult.conflict;
      if (r == DecisionResult.ok) _seen = _store.orderById(widget.orderId)!.status;
    });
    if (r == DecisionResult.ok) toast(context, okMsg);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final o = _store.orderById(widget.orderId)!;
        final e = _store.eventById(o.eventId);
        final pending = _seen == OrderStatus.verifying;
        final history = _store.audit.where((a) => a.orderNumber == o.number).toList();

        final left = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(o.number, style: ts(AppTextSize.h2, w: FontWeight.w800))),
            Chip2(statusLabel(_seen), statusColor(_seen)),
          ]),
          const SizedBox(height: 12),
          if (pending) const Notice('El cliente informó que pagó. Comprueba el depósito en la cuenta bancaria del local antes de confirmar.'),
          if (_conflict) ...[
            const SizedBox(height: 8),
            Notice('Conflicto: ${o.decidedBy ?? 'otro usuario'} ya resolvió esta orden. Solo una decisión puede quedar confirmada; tu acción no se aplicó. Actualiza el estado.', color: AppColors.error, icon: Icons.sync_problem),
          ],
          const SizedBox(height: 12),
          PCard(
            child: Column(children: [
              KV('Evento', e.name),
              KV('Entradas', o.lines.map((l) => '${l.qty} × ${e.types.firstWhere((t) => t.id == l.typeId).name}').join(', ')),
              KV('Importe esperado', money(o.total), vColor: AppColors.accentPrimary),
              KV('Declarado', o.declaredAt == null ? '—' : fmtDateTime(o.declaredAt!)),
              if (pending) KV('Tiempo de espera', waitText(o.declaredAt!), vColor: ageColor(o.declaredAt!)),
            ]),
          ),
          const SizedBox(height: 12),
          PCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Comprador', style: ts(AppTextSize.body, w: FontWeight.w700)),
              KV('Nombre', o.buyerName),
              KV('CI', o.ci),
              KV('Celular', o.phone),
              KV('Correo', o.email ?? 'No indicó'),
            ]),
          ),
        ]);

        final right = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Datos de referencia', style: ts(AppTextSize.body, w: FontWeight.w700)),
              KV('Referencia', o.number),
              if (!_store.live) KV('Beneficiario', ProtoStore.bankBeneficiary),
              KV('Monto', money(o.total)),
              if (!_store.live) ...[
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(8),
                    child: QrImageView(data: 'DEMO-QR-BANCARIO-NO-VALIDO-${o.number}', size: 120, backgroundColor: Colors.white),
                  ),
                ),
                const SizedBox(height: 6),
                Center(child: Text('QR bancario del local (demo)', style: ts(AppTextSize.caption, c: AppColors.textSecondary))),
              ],
              const SizedBox(height: 8),
              Text('La verificación se hace fuera de CHECK, en el banco. CHECK no consulta movimientos bancarios.', style: ts(AppTextSize.caption, c: AppColors.textSecondary, h: 1.4)),
            ]),
          ),
          const SizedBox(height: 12),
          PCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Historial de revisión', style: ts(AppTextSize.body, w: FontWeight.w700)),
              const SizedBox(height: 6),
              if (history.isEmpty && o.declaredAt != null) _hist('Comprador', 'Informó el pago (Ya pagué)', o.declaredAt!),
              for (final a in history) _hist(a.actor, '${a.action} · ${a.result}${a.reason == null ? '' : ' — ${a.reason}'}', a.at),
              if (history.isNotEmpty && o.declaredAt != null) _hist('Comprador', 'Informó el pago (Ya pagué)', o.declaredAt!),
            ]),
          ),
        ]);

        return Scaffold(
          appBar: AppBar(title: Text('Verificación de pago', style: ts(AppTextSize.bodyLg, w: FontWeight.w700))),
          body: ResponsiveBody(
            maxWidth: 1000,
            child: Column(children: [
              LayoutBuilder(builder: (context, c) {
                if (c.maxWidth >= 800) {
                  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 20), Expanded(child: right)]);
                }
                return Column(children: [left, const SizedBox(height: 12), right]);
              }),
              const SizedBox(height: 20),
              if (pending && _allowed) ...[
                PButton('Aprobar pago', icon: Icons.check_circle_outline, loading: _busy, onPressed: _approve),
                const SizedBox(height: 10),
                PButton('Rechazar pago', kind: BtnKind.danger, icon: Icons.block, onPressed: _busy ? null : _reject),
                const SizedBox(height: 10),
                if (!_store.live)
                  TextButton.icon(
                    onPressed: _busy
                        ? null
                        : () {
                            _store.simulateOtherVerifier(o.id);
                            toast(context, 'Otro verificador aprobó esta orden. Tu pantalla aún no lo sabe: intenta decidir.');
                          },
                    icon: const Icon(Icons.groups_outlined, size: 18),
                    label: const Text('Demo: otro verificador resuelve primero'),
                  ),
              ] else if (!pending) ...[
                Notice(
                  o.status == OrderStatus.approved ? 'Pago aprobado por ${o.decidedBy}. ${o.ticketCount} QR individuales generados${_store.live ? '' : ' (demo)'}.' : 'Pago rechazado por ${o.decidedBy}. Decisión definitiva: sin reactivación ni devoluciones.',
                  color: statusColor(o.status),
                  icon: o.status == OrderStatus.approved ? Icons.check_circle_outline : Icons.block,
                ),
                if (_conflict) ...[const SizedBox(height: 10), PButton('Actualizar estado', kind: BtnKind.secondary, icon: Icons.refresh, onPressed: () => setState(() {
                  _conflict = false;
                  _seen = o.status;
                }))],
              ] else
                const Notice('Tu permiso fue revocado: ya no puedes decidir esta orden.', color: AppColors.error, icon: Icons.lock_outline),
            ]),
          ),
        );
      },
    );
  }

  Widget _hist(String who, String what, DateTime at) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(top: 4), child: Icon(Icons.circle, size: 8, color: AppColors.accentPrimary)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(what, style: ts(AppTextSize.body, h: 1.3)),
            Text('$who · ${fmtDateTime(at)}', style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
          ])),
        ]),
      );
}

class _RejectSheet extends StatefulWidget {
  const _RejectSheet();
  @override
  State<_RejectSheet> createState() => _RejectSheetState();
}

class _RejectSheetState extends State<_RejectSheet> {
  final _c = TextEditingController();
  static const _quick = ['No se encontró el depósito', 'El monto no coincide', 'Depósito duplicado o ya usado'];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = _c.text.trim().length >= 5;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Rechazar pago', style: ts(AppTextSize.h3, w: FontWeight.w800)),
              const SizedBox(height: 10),
              const Notice('Esta acción es irreversible: el pedido quedará rechazado de forma definitiva, los cupos se liberarán y no podrá reactivarse. No se gestionan devoluciones desde CHECK.', color: AppColors.error, icon: Icons.warning_amber_rounded),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [for (final q in _quick) ActionChip(label: Text(q), onPressed: () => setState(() => _c.text = q))]),
              const SizedBox(height: 12),
              TextField(controller: _c, maxLines: 2, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Motivo del rechazo (obligatorio)')),
              const SizedBox(height: 16),
              PButton('Rechazar definitivamente', kind: BtnKind.danger, onPressed: valid ? () => Navigator.pop(context, _c.text.trim()) : null),
              const SizedBox(height: 8),
              PButton('Cancelar', kind: BtnKind.secondary, onPressed: () => Navigator.pop(context)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Avisos / escalamiento ─────────────────────────
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key, required this.actor, required this.goToPayments});
  final Actor actor;
  final VoidCallback goToPayments;

  static const _steps = [
    'El comprador pulsa «Ya pagué»',
    'CHECK registra la declaración',
    'El administrador recibe un aviso',
    'La orden entra a la bandeja',
    'Un verificador habilitado puede verla',
    'Se revisa el banco por un canal externo',
    'Se aprueba o rechaza',
    'CHECK actualiza el estado',
  ];

  Future<void> _simulate(BuildContext context) async {
    final r = Random();
    final names = ['Luciana Poma', 'Joaquín Mendoza', 'Daniela Choque', 'Sebastián Torrez'];
    final e = _store.events[r.nextInt(2)];
    final t = e.types.first;
    final q = 1 + r.nextInt(3);
    final o = await _store.createOrder(eventId: e.id, qty: {t.id: q}, name: names[r.nextInt(names.length)], ci: '${6000000 + r.nextInt(3000000)} LP', phone: '7${1000000 + r.nextInt(8999999)}');
    await _store.declarePaid(o.id);
    if (!context.mounted) return;
    toast(context, 'Pago declarado por ${o.buyerName} (simulado)');
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBody(
      maxWidth: 800,
      child: ListenableBuilder(
        listenable: _store,
        builder: (context, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H('Avisos', sub: 'Pagos informados por compradores. Sin WhatsApp, SMS ni push reales.'),
          if (!_store.live) ...[
            PButton('Simular que un comprador pulsa «Ya pagué»', kind: BtnKind.secondary, icon: Icons.bolt, onPressed: () => _simulate(context)),
            const SizedBox(height: 16),
          ],
          for (final n in _store.notifications)
            Builder(builder: (context) {
              final o = _store.orderById(n.orderId)!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.notifications_active_outlined, size: 18, color: PColors.warning),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${o.number} · ${fmtDateTime(n.at)}', style: ts(AppTextSize.caption, c: AppColors.textSecondary))),
                      Chip2(statusLabel(o.status), statusColor(o.status)),
                    ]),
                    const SizedBox(height: 8),
                    Text(n.text, style: ts(AppTextSize.body, h: 1.4)),
                    const SizedBox(height: 6),
                    Text('${o.buyerName} · ${o.ticketCount} entradas · ${money(o.total)}', style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
                    const SizedBox(height: 10),
                    PButton('Revisar pago', onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PaymentDetailScreen(o.id, actor)))),
                  ]),
                ),
              );
            }),
          const SizedBox(height: 12),
          PCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Flujo de verificación', style: ts(AppTextSize.body, w: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final (i, s) in _steps.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    CircleAvatar(radius: 11, backgroundColor: AppColors.accentSubtle, child: Text('${i + 1}', style: ts(11, w: FontWeight.w700, c: AppColors.accentPrimary))),
                    const SizedBox(width: 10),
                    Expanded(child: Text(s, style: ts(AppTextSize.body))),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── Delegación ─────────────────────────
class DelegationPage extends StatelessWidget {
  const DelegationPage({super.key});

  Future<void> _toggle(BuildContext context, Employee e) async {
    final grant = !e.verifier;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: Text(grant ? 'Conceder permiso a ${e.name}' : 'Revocar permiso a ${e.name}'),
        content: Text(grant
            ? '${e.name} podrá ver y resolver solicitudes de verificación bancaria. No tendrá otros permisos de administrador.'
            : '${e.name} dejará de ver solicitudes de pago de inmediato.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(grant ? 'Conceder' : 'Revocar', style: TextStyle(color: grant ? AppColors.accentPrimary : AppColors.error))),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _store.setVerifier(e.id, grant);
      } catch (err) {
        if (context.mounted) toast(context, err is StoreException ? err.message : 'No se pudo cambiar el permiso.', error: true);
        return;
      }
      if (context.mounted) toast(context, _store.live ? (grant ? 'Permiso concedido' : 'Permiso revocado') : (grant ? 'Permiso concedido (simulado)' : 'Permiso revocado (simulado)'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBody(
      maxWidth: 900,
      child: ListenableBuilder(
        listenable: _store,
        builder: (context, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H('Verificadores de confianza', sub: 'Delega solo la verificación de pagos. No es un rol de administrador.'),
          if (!_store.live) const Notice('Propuesta funcional pendiente de aprobación: en este prototipo el permiso está simulado.'),
          const SizedBox(height: 12),
          PCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Qué puede y qué no', style: ts(AppTextSize.body, w: FontWeight.w700)),
              const SizedBox(height: 8),
              _perm(true, 'Ver solicitudes de pago pendientes'),
              _perm(true, 'Aprobar o rechazar pagos tras revisar el banco'),
              _perm(true, 'Ver su propio historial de verificaciones'),
              _perm(false, 'Modificar precios o eventos'),
              _perm(false, 'Administrar personal o permisos'),
              _perm(false, 'Acceder al panel del superadministrador'),
            ]),
          ),
          const SizedBox(height: 16),
          if (_store.live && _store.employees.isEmpty)
            const Notice('Todavía no hay personal. Cuando una persona de tu equipo canjee su código de acceso en un evento, podrás darle permiso de verificar pagos aquí.', icon: Icons.group_outlined, color: PColors.info),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 640 ? 2 : 1;
            final w = (c.maxWidth - (cols - 1) * 12) / cols;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (final e in _store.employees)
                SizedBox(
                  width: w,
                  child: PCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        CircleAvatar(backgroundColor: AppColors.bgBorder, child: Text(e.name[0])),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(e.name, style: ts(AppTextSize.bodyLg, w: FontWeight.w600)),
                          Text(e.job, style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
                        ])),
                        Chip2(e.verifier ? 'Permiso activo' : 'Sin permiso', e.verifier ? AppColors.success : AppColors.textSecondary),
                      ]),
                      const SizedBox(height: 10),
                      Text(e.verifier ? 'Concedido ${fmtDate(e.grantedAt!)} · ${_store.verificationsBy(e.name)} verificaciones' : 'Verificaciones: ${_store.verificationsBy(e.name)}', style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: PButton(e.verifier ? 'Revocar permiso' : 'Conceder permiso', kind: e.verifier ? BtnKind.danger : BtnKind.primary, onPressed: () => _toggle(context, e))),
                        const SizedBox(width: 8),
                        IconButton.outlined(tooltip: 'Ver verificaciones', onPressed: () => _showHistory(context, e), icon: const Icon(Icons.history)),
                      ]),
                    ]),
                  ),
                ),
            ]);
          }),
        ]),
      ),
    );
  }

  Widget _perm(bool yes, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Icon(yes ? Icons.check_circle : Icons.cancel, size: 18, color: yes ? AppColors.success : AppColors.error),
          const SizedBox(width: 10),
          Expanded(child: Text(t, style: ts(AppTextSize.body))),
        ]),
      );

  void _showHistory(BuildContext context, Employee e) {
    final list = _store.audit.where((a) => a.actor == e.name).toList();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgSurface,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, sc) => ListView(controller: sc, padding: const EdgeInsets.all(20), children: [
          Text('Verificaciones de ${e.name}', style: ts(AppTextSize.h3, w: FontWeight.w800)),
          const SizedBox(height: 12),
          if (list.isEmpty) const StateView(ViewState.empty, message: 'Aún no realizó verificaciones.'),
          for (final a in list) AuditTile(a),
        ]),
      ),
    );
  }
}

// ───────────────────────── Historial / auditoría ─────────────────────────
class AuditTile extends StatelessWidget {
  const AuditTile(this.a, {super.key});
  final AuditEntry a;
  @override
  Widget build(BuildContext context) {
    final color = a.action.contains('Aprobó') ? AppColors.success : (a.action.contains('Rechazó') || a.action.contains('bloqueado') || a.action.contains('Revocó')) ? AppColors.error : PColors.info;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(a.action, style: ts(AppTextSize.body, w: FontWeight.w700, c: color))),
            Text(fmtDateTime(a.at), style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
          ]),
          const SizedBox(height: 6),
          KV('Empleado', a.actor),
          KV('Permiso', a.permission),
          if (a.orderNumber != null) KV('Orden', a.orderNumber!),
          if (a.venue != null) KV('Local', a.venue!),
          KV('Resultado', a.result),
          if (a.reason != null) KV('Motivo / detalle', a.reason!),
        ]),
      ),
    );
  }
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.actor, required this.onlyMine});
  final Actor actor;
  final bool onlyMine;
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String _f = 'all';
  @override
  Widget build(BuildContext context) {
    return ResponsiveBody(
      maxWidth: 800,
      child: ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          var list = _store.audit.where((a) => !widget.onlyMine || a.actor == widget.actor.name).toList();
          list = list.where((a) => switch (_f) {
                'ok' => a.action.contains('Aprobó'),
                'ko' => a.action.contains('Rechazó') || a.action.contains('bloqueado'),
                'perm' => a.action.contains('permiso'),
                _ => true,
              }).toList();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            H(widget.onlyMine ? 'Mis verificaciones' : 'Historial y auditoría', sub: 'Cada acción queda registrada con empleado, permiso, orden, resultado y hora.'),
            Wrap(spacing: 8, children: [
              for (final (k, l) in const [('all', 'Todo'), ('ok', 'Aprobaciones'), ('ko', 'Rechazos / bloqueos'), ('perm', 'Permisos')])
                if (!(widget.onlyMine && k == 'perm')) ChoiceChip(label: Text(l), selected: _f == k, onSelected: (_) => setState(() => _f = k)),
            ]),
            const SizedBox(height: 14),
            if (list.isEmpty) const StateView(ViewState.empty, message: 'Sin registros.'),
            for (final a in list) AuditTile(a),
          ]);
        },
      ),
    );
  }
}
