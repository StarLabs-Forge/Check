import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../theme/app_theme.dart';
import '../data/proto_store.dart';
import '../widgets/proto_ui.dart';

final _store = ProtoStore.instance;

// ───────────────────────── A1 · Exploración ─────────────────────────
class BuyerHome extends StatefulWidget {
  const BuyerHome({super.key});
  @override
  State<BuyerHome> createState() => _BuyerHomeState();
}

class _BuyerHomeState extends State<BuyerHome> {
  String _q = '';
  String? _venue;
  bool _onlyAvailable = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('CHECK.', style: ts(20, w: FontWeight.w800, c: AppColors.accentPrimary)),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OrderLookupScreen())),
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: const Text('Mi pedido'),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          var list = _store.events.where((e) => e.state != EventState.finished).toList();
          if (_q.isNotEmpty) list = list.where((e) => e.name.toLowerCase().contains(_q.toLowerCase())).toList();
          if (_venue != null) list = list.where((e) => e.venueId == _venue).toList();
          if (_onlyAvailable) list = list.where((e) => e.types.any((t) => _store.remaining(t) > 0)).toList();
          final featured = _store.events.where((e) => e.state == EventState.active).take(2).toList();

          return ResponsiveBody(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const H('Eventos', sub: 'Compra tus entradas sin crear una cuenta.'),
              if (featured.isNotEmpty) ...[
                Text('Destacados', style: ts(AppTextSize.h3, w: FontWeight.w700)),
                const SizedBox(height: 12),
                LayoutBuilder(builder: (context, c) {
                  final cols = c.maxWidth >= 720 ? 2 : 1;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final e in featured)
                        SizedBox(width: (c.maxWidth - (cols - 1) * 16) / cols, child: _EventCard(e, featured: true)),
                    ],
                  );
                }),
                const SizedBox(height: 28),
              ],
              Text('Todos los eventos', style: ts(AppTextSize.h3, w: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setState(() => _q = v),
                style: ts(AppTextSize.body),
                decoration: const InputDecoration(hintText: 'Buscar evento', prefixIcon: Icon(Icons.search)),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  FilterChip(label: const Text('Todos los locales'), selected: _venue == null, onSelected: (_) => setState(() => _venue = null)),
                  for (final v in _store.venues.where((v) => v.active)) ...[
                    const SizedBox(width: 8),
                    FilterChip(label: Text(v.name), selected: _venue == v.id, onSelected: (s) => setState(() => _venue = s ? v.id : null)),
                  ],
                  const SizedBox(width: 8),
                  FilterChip(label: const Text('Con disponibilidad'), selected: _onlyAvailable, onSelected: (s) => setState(() => _onlyAvailable = s)),
                ]),
              ),
              const SizedBox(height: 16),
              if (list.isEmpty)
                const StateView(ViewState.empty, message: 'No hay eventos con esos filtros.')
              else
                LayoutBuilder(builder: (context, c) {
                  final cols = c.maxWidth >= 900 ? 3 : (c.maxWidth >= 560 ? 2 : 1);
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [for (final e in list) SizedBox(width: (c.maxWidth - (cols - 1) * 16) / cols, child: _EventCard(e))],
                  );
                }),
            ]),
          );
        },
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard(this.e, {this.featured = false});
  final EventItem e;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final left = e.types.fold(0, (s, t) => s + _store.remaining(t));
    final soldOut = left == 0;
    final low = !soldOut && left <= 20;
    return PCard(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventDetailScreen(e.id))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Cover(e.hue, height: featured ? 170 : 120, radius: AppRadius.lg),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.name, style: ts(AppTextSize.h3, w: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${fmtDate(e.date)} · ${fmtTime(e.date)}', style: ts(AppTextSize.body, c: AppColors.textSecondary)),
            Text(e.place, style: ts(AppTextSize.body, c: AppColors.textSecondary)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Text('Desde ${money(e.fromPrice)}', style: ts(AppTextSize.bodyLg, w: FontWeight.w700, c: AppColors.accentPrimary))),
              if (soldOut) const Chip2('Agotado', AppColors.error) else if (low) Chip2('Quedan $left', PColors.warning) else const Chip2('Disponible', AppColors.success),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ───────────────────────── A2 · Detalle ─────────────────────────
class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen(this.eventId, {super.key});
  final String eventId;

  @override
  Widget build(BuildContext context) {
    final e = _store.eventById(eventId);
    final v = _store.venueById(e.venueId);
    final anyLeft = e.types.any((t) => _store.remaining(t) > 0);

    final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(e.name, style: ts(Bp.isMobile(context) ? 26 : 32, w: FontWeight.w800)),
      const SizedBox(height: 12),
      _line(Icons.event, '${fmtDate(e.date)} · ${fmtTime(e.date)}'),
      _line(Icons.place_outlined, e.place),
      _line(Icons.storefront_outlined, 'Organiza: ${v.name}'),
      const SizedBox(height: 16),
      Text(e.description, style: ts(AppTextSize.bodyLg, c: AppColors.textSecondary, h: 1.5)),
    ]);

    final tickets = PCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Entradas', style: ts(AppTextSize.h3, w: FontWeight.w700)),
        const SizedBox(height: 8),
        for (final t in e.types)
          ListenableBuilder(
            listenable: _store,
            builder: (_, _) {
              final r = _store.remaining(t);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.name, style: ts(AppTextSize.bodyLg, w: FontWeight.w600)),
                    Text(r == 0 ? 'Agotado' : '$r disponibles', style: ts(AppTextSize.caption, c: r == 0 ? AppColors.error : AppColors.textSecondary)),
                  ])),
                  Text(money(t.price), style: ts(AppTextSize.bodyLg, w: FontWeight.w700, c: AppColors.accentPrimary)),
                ]),
              );
            },
          ),
        const SizedBox(height: 8),
        PButton(anyLeft ? 'Comprar entradas' : 'Agotado',
            onPressed: anyLeft ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TicketSelectionScreen(e.id))) : null),
      ]),
    );

    return Scaffold(
      appBar: AppBar(),
      body: ResponsiveBody(
        maxWidth: 1000,
        child: LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 800;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Cover(e.hue, height: wide ? 260 : 180),
            const SizedBox(height: 20),
            if (wide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 6, child: info),
                const SizedBox(width: 24),
                Expanded(flex: 4, child: tickets),
              ])
            else ...[info, const SizedBox(height: 20), tickets],
          ]);
        }),
      ),
    );
  }

  Widget _line(IconData i, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [Icon(i, size: 18, color: AppColors.textSecondary), const SizedBox(width: 10), Expanded(child: Text(t, style: ts(AppTextSize.bodyLg)))]),
      );
}

// ───────────────────────── A3 · Selección ─────────────────────────
class TicketSelectionScreen extends StatefulWidget {
  const TicketSelectionScreen(this.eventId, {super.key});
  final String eventId;
  @override
  State<TicketSelectionScreen> createState() => _TicketSelectionState();
}

class _TicketSelectionState extends State<TicketSelectionScreen> {
  final Map<String, int> _qty = {};

  int _max(TicketType t) {
    final r = _store.remaining(t);
    return r < t.maxPerOrder ? r : t.maxPerOrder;
  }

  @override
  Widget build(BuildContext context) {
    final e = _store.eventById(widget.eventId);
    final total = e.types.fold<double>(0, (s, t) => s + (_qty[t.id] ?? 0) * t.price);
    final count = _qty.values.fold(0, (s, q) => s + q);

    final selector = Column(children: [
      for (final t in e.types)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PCard(
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.name, style: ts(AppTextSize.bodyLg, w: FontWeight.w700)),
                Text('${money(t.price)} c/u', style: ts(AppTextSize.body, c: AppColors.textSecondary)),
                Text(_max(t) == 0 ? 'Agotado' : 'Máx. ${_max(t)} por pedido · quedan ${_store.remaining(t)}', style: ts(AppTextSize.caption, c: _max(t) == 0 ? AppColors.error : AppColors.textSecondary)),
              ])),
              _Stepper(
                value: _qty[t.id] ?? 0,
                max: _max(t),
                onChanged: (v) => setState(() => _qty[t.id] = v),
              ),
            ]),
          ),
        ),
    ]);

    final summary = PCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Resumen', style: ts(AppTextSize.h3, w: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(e.name, style: ts(AppTextSize.body, c: AppColors.textSecondary)),
        const Divider(height: 24),
        if (count == 0) Text('Aún no seleccionaste entradas.', style: ts(AppTextSize.body, c: AppColors.textSecondary)),
        for (final t in e.types)
          if ((_qty[t.id] ?? 0) > 0) KV('${_qty[t.id]} × ${t.name}', money(_qty[t.id]! * t.price)),
        const Divider(height: 24),
        Row(children: [
          Expanded(child: Text('Total', style: ts(AppTextSize.bodyLg, w: FontWeight.w700))),
          Text(money(total), style: ts(AppTextSize.h3, w: FontWeight.w800, c: AppColors.accentPrimary)),
        ]),
        const SizedBox(height: 16),
        PButton('Continuar',
            onPressed: count == 0
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BuyerDataScreen(eventId: e.id, qty: Map.of(_qty)))))
      ]),
    );

    return Scaffold(
      appBar: AppBar(title: Text('Elige tus entradas', style: ts(AppTextSize.bodyLg, w: FontWeight.w700))),
      body: ResponsiveBody(
        maxWidth: 1000,
        child: LayoutBuilder(builder: (context, c) {
          if (c.maxWidth >= 800) {
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 6, child: selector),
              const SizedBox(width: 24),
              Expanded(flex: 4, child: summary),
            ]);
          }
          return Column(children: [selector, summary]);
        }),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.max, required this.onChanged});
  final int value;
  final int max;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton.outlined(
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove),
          tooltip: 'Quitar una',
        ),
        SizedBox(width: 36, child: Center(child: Text('$value', style: ts(AppTextSize.bodyLg, w: FontWeight.w700)))),
        IconButton.outlined(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add),
          tooltip: 'Agregar una',
        ),
      ]);
}

// ───────────────────────── A4 · Datos ─────────────────────────
class BuyerDataScreen extends StatefulWidget {
  const BuyerDataScreen({super.key, required this.eventId, required this.qty});
  final String eventId;
  final Map<String, int> qty;
  @override
  State<BuyerDataScreen> createState() => _BuyerDataState();
}

class _BuyerDataState extends State<BuyerDataScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _ci = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _ci, _phone, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final o = _store.createOrder(
      eventId: widget.eventId,
      qty: widget.qty,
      name: _name.text.trim(),
      ci: _ci.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text,
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => OrderScreen(o.id)),
      (r) => r.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = _store.eventById(widget.eventId);
    final total = widget.qty.entries.fold<double>(0, (s, en) => s + en.value * e.types.firstWhere((t) => t.id == en.key).price);
    return Scaffold(
      appBar: AppBar(title: Text('Tus datos', style: ts(AppTextSize.bodyLg, w: FontWeight.w700))),
      body: ResponsiveBody(
        maxWidth: 560,
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PCard(child: Row(children: [
              Expanded(child: Text('${e.name} · ${widget.qty.values.fold(0, (a, b) => a + b)} entradas', style: ts(AppTextSize.body))),
              Text(money(total), style: ts(AppTextSize.bodyLg, w: FontWeight.w700, c: AppColors.accentPrimary)),
            ])),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre completo *'),
              validator: (v) => (v == null || v.trim().split(' ').where((p) => p.isNotEmpty).length < 2) ? 'Ingresa nombre y apellido' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _ci,
              decoration: const InputDecoration(labelText: 'Número de CI *', hintText: 'Ej. 8123456 LP'),
              validator: (v) => RegExp(r'^\d{5,9}(\s?[A-Za-z]{1,3})?$').hasMatch((v ?? '').trim()) ? null : 'CI no válido',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Celular *', prefixText: '+591 '),
              validator: (v) => RegExp(r'^[67]\d{7}$').hasMatch((v ?? '').replaceAll(' ', '')) ? null : 'Celular de 8 dígitos que empiece con 6 o 7',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Correo (opcional)'),
              validator: (v) => (v == null || v.trim().isEmpty || v.contains('@')) ? null : 'Correo no válido',
            ),
            const SizedBox(height: 8),
            Text('Si agregas tu correo, también te enviaremos tus entradas cuando se confirme el pago.', style: ts(AppTextSize.caption, c: AppColors.textSecondary, h: 1.4)),
            const SizedBox(height: 8),
            Text('No necesitas crear una cuenta ni una contraseña.', style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
            const SizedBox(height: 24),
            PButton('Continuar al pago', loading: _busy, onPressed: _submit),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────── B · Pedido (según estado) ─────────────────────────
class OrderScreen extends StatelessWidget {
  const OrderScreen(this.orderId, {super.key});
  final String orderId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final o = _store.orderById(orderId);
        if (o == null) {
          return Scaffold(appBar: AppBar(), body: const StateView(ViewState.error, message: 'No encontramos ese pedido.'));
        }
        final body = switch (o.status) {
          OrderStatus.awaitingPayment => _PendingPayment(o),
          OrderStatus.verifying => _Verifying(o),
          OrderStatus.approved => _Approved(o),
          OrderStatus.rejected => _Rejected(o),
          OrderStatus.expired || OrderStatus.cancelled => _Closed(o),
        };
        return Scaffold(
          appBar: AppBar(title: Text('Pedido ${o.number}', style: ts(AppTextSize.bodyLg, w: FontWeight.w700))),
          body: ResponsiveBody(maxWidth: 640, child: body),
        );
      },
    );
  }
}

Widget _summary(Order o) {
  final e = _store.eventById(o.eventId);
  return PCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(e.name, style: ts(AppTextSize.h3, w: FontWeight.w700)),
      Text('${fmtDateTime(e.date)} · ${e.place}', style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
      const Divider(height: 24),
      for (final l in o.lines) KV('${l.qty} × ${e.types.firstWhere((t) => t.id == l.typeId).name}', money(l.qty * e.types.firstWhere((t) => t.id == l.typeId).price)),
      const Divider(height: 24),
      Row(children: [
        Expanded(child: Text('Total', style: ts(AppTextSize.bodyLg, w: FontWeight.w700))),
        Text(money(o.total), style: ts(AppTextSize.h3, w: FontWeight.w800, c: AppColors.accentPrimary)),
      ]),
    ]),
  );
}

Widget _privateLink(Order o) => PCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Tu enlace privado', style: ts(AppTextSize.body, w: FontWeight.w600)),
        const SizedBox(height: 4),
        SelectableText('check.app/pedido/${o.token}', style: ts(AppTextSize.body, c: AppColors.accentPrimary)),
        const SizedBox(height: 6),
        Text('Guárdalo: es la única forma de volver a ver tu pedido. No hay cuenta ni recuperación por SMS.', style: ts(AppTextSize.caption, c: AppColors.textSecondary, h: 1.4)),
      ]),
    );

// B1
class _PendingPayment extends StatefulWidget {
  const _PendingPayment(this.o);
  final Order o;
  @override
  State<_PendingPayment> createState() => _PendingPaymentState();
}

class _PendingPaymentState extends State<_PendingPayment> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _store.expireIfNeeded(widget.o.id);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.o;
    final left = o.expiresAt.difference(DateTime.now());
    final s = left.isNegative ? 0 : left.inSeconds;
    final clock = '${two(s ~/ 60)}:${two(s % 60)}';
    final urgent = s < 180;

    final qr = PCard(
      child: Column(children: [
        Text('Paga con el QR bancario del local', style: ts(AppTextSize.bodyLg, w: FontWeight.w700), textAlign: TextAlign.center),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: QrImageView(data: 'DEMO-QR-BANCARIO-NO-VALIDO-${o.number}', size: 190, backgroundColor: Colors.white),
        ),
        const SizedBox(height: 8),
        const Chip2('QR de demostración · no válido para pagar', PColors.warning),
        const SizedBox(height: 14),
        KV('Beneficiario', ProtoStore.bankBeneficiary),
        KV('Monto a pagar', money(o.total)),
      ]),
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PCard(
        color: (urgent ? AppColors.error : PColors.warning).withValues(alpha: 0.10),
        border: (urgent ? AppColors.error : PColors.warning).withValues(alpha: 0.5),
        child: Row(children: [
          Icon(Icons.timer_outlined, color: urgent ? AppColors.error : PColors.warning),
          const SizedBox(width: 12),
          Expanded(child: Text('Tienes este tiempo para pagar y avisar', style: ts(AppTextSize.body))),
          Text(clock, style: ts(26, w: FontWeight.w800, c: urgent ? AppColors.error : PColors.warning)),
        ]),
      ),
      const SizedBox(height: 16),
      _summary(o),
      const SizedBox(height: 16),
      qr,
      const SizedBox(height: 16),
      PCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Instrucciones', style: ts(AppTextSize.body, w: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final (i, t) in ['Abre la app de tu banco y escanea el QR.', 'Paga exactamente ${money(o.total)}.', 'Vuelve aquí y pulsa «Ya pagué».'].indexed)
            Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text('${i + 1}. $t', style: ts(AppTextSize.body, c: AppColors.textSecondary))),
        ]),
      ),
      const SizedBox(height: 16),
      PButton('Ya pagué', icon: Icons.check, onPressed: () {
        _store.declarePaid(o.id);
      }),
      const SizedBox(height: 10),
      PButton('Cancelar pedido', kind: BtnKind.secondary, onPressed: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            backgroundColor: AppColors.bgSurface,
            title: const Text('¿Cancelar el pedido?'),
            content: const Text('Se liberarán tus entradas reservadas.'),
            actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Volver')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sí, cancelar'))],
          ),
        );
        if (ok == true) _store.cancelOrder(o.id);
      }),
    ]);
  }
}

// B2
class _Verifying extends StatelessWidget {
  const _Verifying(this.o);
  final Order o;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Column(children: [
          const SizedBox(height: 8),
          const SizedBox(width: 52, height: 52, child: CircularProgressIndicator(color: PColors.warning, strokeWidth: 4)),
          const SizedBox(height: 16),
          Text('Estamos verificando tu pago', style: ts(AppTextSize.h2, w: FontWeight.w800), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('Pedido ${o.number}', style: ts(AppTextSize.bodyLg, c: AppColors.textSecondary)),
        ])),
        const SizedBox(height: 20),
        const Notice('Informaste tu pago. El local debe comprobar el depósito en su cuenta bancaria. Todavía no se ha confirmado que lo recibió y tus entradas aún no están habilitadas.'),
        const SizedBox(height: 16),
        _summary(o),
        const SizedBox(height: 16),
        _privateLink(o),
        const SizedBox(height: 16),
        Text('Esta pantalla se actualiza sola cuando el local decida.', textAlign: TextAlign.center, style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
      ]);
}

// B5
class _Approved extends StatelessWidget {
  const _Approved(this.o);
  final Order o;
  @override
  Widget build(BuildContext context) {
    final e = _store.eventById(o.eventId);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: Column(children: [
        const Icon(Icons.check_circle, color: AppColors.success, size: 56),
        const SizedBox(height: 8),
        Text('Pago aprobado', style: ts(AppTextSize.h2, w: FontWeight.w800)),
        Text('${o.ticketCount} ${o.ticketCount == 1 ? 'entrada' : 'entradas'} · ${e.name}', style: ts(AppTextSize.body, c: AppColors.textSecondary)),
      ])),
      const SizedBox(height: 16),
      const Notice(
        'Cuida tu código QR y no lo compartas con otras personas. Cada QR permite un único ingreso. Si alguien lo utiliza antes que tú, podría impedirte el acceso al evento.',
        color: AppColors.error,
        icon: Icons.warning_amber_rounded,
      ),
      const SizedBox(height: 8),
      const Notice('Entradas de demostración: los QR no son válidos en ningún evento real.', icon: Icons.science_outlined),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 520 ? 2 : 1;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (var i = 0; i < o.ticketCodes.length; i++)
            SizedBox(width: (c.maxWidth - (cols - 1) * 12) / cols, child: _TicketCard(o, i)),
        ]);
      }),
      const SizedBox(height: 16),
      if (o.email != null) Notice('También enviaremos tus entradas a ${o.email} (simulado).', color: AppColors.success, icon: Icons.mail_outline),
      if (o.ticketCount > 1) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Compra grupal: cada persona necesita su propio QR.', style: ts(AppTextSize.caption, c: AppColors.textSecondary))),
      const SizedBox(height: 16),
      _privateLink(o),
    ]);
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard(this.o, this.i);
  final Order o;
  final int i;
  @override
  Widget build(BuildContext context) {
    final code = o.ticketCodes[i];
    return PCard(
      child: Column(children: [
        Row(children: [
          Expanded(child: Text('Entrada ${i + 1} de ${o.ticketCount}', style: ts(AppTextSize.body, w: FontWeight.w700))),
          const Chip2('Demo · no válida', PColors.warning),
        ]),
        const SizedBox(height: 12),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(10),
          child: Stack(alignment: Alignment.center, children: [
            QrImageView(data: 'INVALID-DEMO-$code', size: 150, backgroundColor: Colors.white),
          ]),
        ),
        const SizedBox(height: 6),
        Text(code, style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
        Text('QR de demostración · no válido en ningún evento', style: ts(AppTextSize.caption, w: FontWeight.w700, c: PColors.warning)),
        const SizedBox(height: 10),
        PButton('Descargar QR', kind: BtnKind.secondary, icon: Icons.download, onPressed: () => toast(context, 'Descarga simulada de $code')),
      ]),
    );
  }
}

// B6
class _Rejected extends StatelessWidget {
  const _Rejected(this.o);
  final Order o;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Column(children: [
          const Icon(Icons.cancel, color: AppColors.error, size: 56),
          const SizedBox(height: 8),
          Text('Pago rechazado', style: ts(AppTextSize.h2, w: FontWeight.w800)),
        ])),
        const SizedBox(height: 16),
        Notice('El local no pudo confirmar tu depósito.${o.rejectReason == null ? '' : ' Motivo: ${o.rejectReason}'}', color: AppColors.error, icon: Icons.info_outline),
        const SizedBox(height: 8),
        const Notice('Esta decisión es definitiva: el pedido no se puede reactivar y tus cupos fueron liberados. Si crees que es un error, comunícate directamente con el local.'),
        const SizedBox(height: 16),
        _summary(o),
        const SizedBox(height: 16),
        PButton('Ver otros eventos', kind: BtnKind.secondary, onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst)),
      ]);
}

class _Closed extends StatelessWidget {
  const _Closed(this.o);
  final Order o;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        StateView(ViewState.empty, message: o.status == OrderStatus.expired ? 'El tiempo para pagar terminó y las entradas se liberaron.' : 'Cancelaste este pedido.'),
        PButton('Volver a eventos', onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst)),
      ]);
}

// ───────────────────────── B7 · Consulta privada ─────────────────────────
class OrderLookupScreen extends StatefulWidget {
  const OrderLookupScreen({super.key});
  @override
  State<OrderLookupScreen> createState() => _OrderLookupState();
}

class _OrderLookupState extends State<OrderLookupScreen> {
  final _c = TextEditingController();
  String? _err;

  void _go() {
    final o = _store.orderByToken(_c.text);
    if (o == null) {
      setState(() => _err = 'No encontramos un pedido con ese enlace o número.');
      return;
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => OrderScreen(o.id)));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Consultar mi pedido', style: ts(AppTextSize.bodyLg, w: FontWeight.w700))),
        body: ResponsiveBody(
          maxWidth: 520,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const H('Abre tu enlace privado', sub: 'Pega el código de tu enlace (o el número de pedido). No necesitas iniciar sesión.'),
            TextField(controller: _c, onSubmitted: (_) => _go(), decoration: InputDecoration(labelText: 'Código o número de pedido', errorText: _err)),
            const SizedBox(height: 16),
            PButton('Ver pedido', onPressed: _go),
            const SizedBox(height: 20),
            Text('Para probar, usa un pedido de ejemplo:', style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final o in _store.orders.take(5)) ActionChip(label: Text(o.number), onPressed: () => setState(() => _c.text = o.number)),
            ]),
          ]),
        ),
      );
}
