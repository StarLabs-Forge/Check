import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../theme/app_theme.dart';
import '../../widgets/auth_scaffold.dart' show FieldPair;
import '../../widgets/motion.dart';
import '../data/proto_store.dart';
import '../widgets/proto_ui.dart';

final _store = ProtoStore.instance;

/// Pantallas anchas muestran dos columnas; en celulares el paso cabe en una
/// vista y su acción principal queda fija al pie.
bool _wide(BuildContext c) => MediaQuery.sizeOf(c).width >= 860;

/// Marca las pantallas del flujo de compra (detalle → entradas → datos) para
/// poder cerrarlas todas juntas y abrir el pago como ventana emergente.
const _flow = 'buy-flow';
RouteSettings get _flowRoute => const RouteSettings(arguments: _flow);

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
    final pad = Bp.isMobile(context) ? AppSpacing.s4 : AppSpacing.s6;
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
          final filtering = _q.isNotEmpty || _venue != null || _onlyAvailable;

          // Búsqueda y filtros quedan fijos arriba: siempre a un toque.
          return Column(children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(pad, AppSpacing.s2, pad, AppSpacing.s2),
                  child: Reveal(
                    dy: -6,
                    child: Column(children: [
                      TextField(
                        onChanged: (v) => setState(() => _q = v),
                        style: ts(AppTextSize.body),
                        decoration: const InputDecoration(hintText: 'Buscar evento · compra sin crear cuenta', prefixIcon: Icon(Icons.search)),
                      ),
                      const SizedBox(height: 8),
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
                    ]),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ResponsiveBody(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  AnimatedSize(
                    duration: Motion.base,
                    curve: Motion.enter,
                    alignment: Alignment.topCenter,
                    child: (featured.isEmpty || filtering)
                        ? const SizedBox(width: double.infinity)
                        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Destacados', style: ts(AppTextSize.h3, w: FontWeight.w700)),
                            const SizedBox(height: 10),
                            LayoutBuilder(builder: (context, c) {
                              if (c.maxWidth >= 720) {
                                return Row(children: [
                                  for (final (i, e) in featured.indexed) ...[
                                    if (i > 0) const SizedBox(width: 16),
                                    Expanded(child: Reveal(delay: Reveal.stagger(i), child: _EventCard(e, featured: true))),
                                  ],
                                ]);
                              }
                              // Celular: carrusel horizontal, ocupa una sola franja.
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                clipBehavior: Clip.none,
                                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  for (final (i, e) in featured.indexed) ...[
                                    if (i > 0) const SizedBox(width: 12),
                                    SizedBox(
                                      width: c.maxWidth * 0.82,
                                      child: Reveal(dx: 20, dy: 0, delay: Reveal.stagger(i), child: _EventCard(e, featured: true)),
                                    ),
                                  ],
                                ]),
                              );
                            }),
                            const SizedBox(height: 20),
                          ]),
                  ),
                  Text(filtering ? 'Resultados' : 'Todos los eventos', style: ts(AppTextSize.h3, w: FontWeight.w700)),
                  const SizedBox(height: 10),
                  if (list.isEmpty)
                    const StateView(ViewState.empty, message: 'No hay eventos con esos filtros.')
                  else
                    LayoutBuilder(builder: (context, c) {
                      final cols = c.maxWidth >= 900 ? 3 : (c.maxWidth >= 560 ? 2 : 1);
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          for (final (i, e) in list.indexed)
                            SizedBox(
                              key: ValueKey(e.id),
                              width: (c.maxWidth - (cols - 1) * 16) / cols,
                              child: Reveal(delay: Reveal.stagger(i), child: _EventCard(e, heroTag: 'cover-${e.id}')),
                            ),
                        ],
                      );
                    }),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard(this.e, {this.featured = false, this.heroTag});
  final EventItem e;
  final bool featured;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final left = e.types.fold(0, (s, t) => s + _store.remaining(t));
    final soldOut = left == 0;
    final low = !soldOut && left <= 20;
    return PCard(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(settings: _flowRoute, builder: (_) => EventDetailScreen(e.id, heroTag: heroTag))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Cover(e.hue, height: featured ? 120 : 110, radius: AppRadius.lg, heroTag: heroTag),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(AppTextSize.h3, w: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${fmtDate(e.date)} · ${fmtTime(e.date)} · ${e.place}', maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(AppTextSize.body, c: AppColors.textSecondary)),
            const SizedBox(height: 10),
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
  const EventDetailScreen(this.eventId, {super.key, this.heroTag});
  final String eventId;
  final String? heroTag;

  void _buy(BuildContext context, String id) =>
      Navigator.of(context).push(MaterialPageRoute(settings: _flowRoute, builder: (_) => TicketSelectionScreen(id)));

  @override
  Widget build(BuildContext context) {
    final e = _store.eventById(eventId);
    final v = _store.venueById(e.venueId);
    final anyLeft = e.types.any((t) => _store.remaining(t) > 0);
    final wide = _wide(context);

    final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(e.name, style: ts(wide ? 32 : 24, w: FontWeight.w800)),
      const SizedBox(height: 8),
      _line(Icons.event, '${fmtDate(e.date)} · ${fmtTime(e.date)}'),
      _line(Icons.place_outlined, e.place),
      _line(Icons.storefront_outlined, 'Organiza: ${v.name}'),
      const SizedBox(height: 12),
      Text(e.description, style: ts(wide ? AppTextSize.bodyLg : AppTextSize.body, c: AppColors.textSecondary, h: 1.45)),
    ]);

    final tickets = PCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Entradas', style: ts(AppTextSize.h3, w: FontWeight.w700)),
        const SizedBox(height: 4),
        for (final t in e.types)
          ListenableBuilder(
            listenable: _store,
            builder: (_, _) {
              final r = _store.remaining(t);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
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
        if (wide) ...[
          const SizedBox(height: 8),
          PButton(anyLeft ? 'Comprar entradas' : 'Agotado', onPressed: anyLeft ? () => _buy(context, e.id) : null),
        ],
      ]),
    );

    final bar = Row(children: [
      Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Desde', style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
        Text(money(e.fromPrice), style: ts(AppTextSize.h3, w: FontWeight.w800, c: AppColors.accentPrimary)),
      ]),
      const SizedBox(width: 16),
      Expanded(child: PButton(anyLeft ? 'Comprar entradas' : 'Agotado', onPressed: anyLeft ? () => _buy(context, e.id) : null)),
    ]);

    return Scaffold(
      appBar: AppBar(),
      bottomNavigationBar: wide ? null : BottomActionBar(maxWidth: 1000, child: bar),
      body: ResponsiveBody(
        maxWidth: 1000,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Cover(e.hue, height: wide ? 240 : 130, heroTag: heroTag),
          SizedBox(height: wide ? 20 : 14),
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 6, child: Reveal(delay: const Duration(milliseconds: 80), child: info)),
              const SizedBox(width: 24),
              Expanded(flex: 4, child: Reveal(delay: const Duration(milliseconds: 160), child: tickets)),
            ])
          else ...[
            Reveal(delay: const Duration(milliseconds: 80), child: info),
            const SizedBox(height: 14),
            Reveal(delay: const Duration(milliseconds: 160), child: tickets),
          ],
        ]),
      ),
    );
  }

  Widget _line(IconData i, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [Icon(i, size: 18, color: AppColors.textSecondary), const SizedBox(width: 10), Expanded(child: Text(t, style: ts(AppTextSize.body)))]),
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

  void _next(EventItem e) => Navigator.of(context).push(MaterialPageRoute(settings: _flowRoute, builder: (_) => BuyerDataScreen(eventId: e.id, qty: Map.of(_qty))));

  @override
  Widget build(BuildContext context) {
    final e = _store.eventById(widget.eventId);
    final total = e.types.fold<double>(0, (s, t) => s + (_qty[t.id] ?? 0) * t.price);
    final count = _qty.values.fold(0, (s, q) => s + q);
    final wide = _wide(context);

    final selector = Column(children: [
      for (final (i, t) in e.types.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Reveal(
            delay: Reveal.stagger(i),
            child: PCard(
              color: (_qty[t.id] ?? 0) > 0 ? AppColors.accentSubtle : null,
              border: (_qty[t.id] ?? 0) > 0 ? AppColors.accentPrimary.withValues(alpha: 0.6) : null,
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.name, style: ts(AppTextSize.bodyLg, w: FontWeight.w700)),
                  Text('${money(t.price)} c/u', style: ts(AppTextSize.body, c: AppColors.accentPrimary, w: FontWeight.w600)),
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
        ),
    ]);

    final summary = PCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Resumen', style: ts(AppTextSize.h3, w: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(e.name, style: ts(AppTextSize.body, c: AppColors.textSecondary)),
        const Divider(height: 24),
        AnimatedSize(
          duration: Motion.base,
          curve: Motion.enter,
          alignment: Alignment.topCenter,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (count == 0) Text('Aún no seleccionaste entradas.', style: ts(AppTextSize.body, c: AppColors.textSecondary)),
            for (final t in e.types)
              if ((_qty[t.id] ?? 0) > 0) KV('${_qty[t.id]} × ${t.name}', money(_qty[t.id]! * t.price)),
          ]),
        ),
        const Divider(height: 24),
        Row(children: [
          Expanded(child: Text('Total', style: ts(AppTextSize.bodyLg, w: FontWeight.w700))),
          AnimatedCount(money(total), duration: const Duration(milliseconds: 350), style: ts(AppTextSize.h3, w: FontWeight.w800, c: AppColors.accentPrimary)),
        ]),
        const SizedBox(height: 16),
        PButton('Continuar', onPressed: count == 0 ? null : () => _next(e)),
      ]),
    );

    final bar = Row(children: [
      Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(count == 0 ? 'Sin entradas' : '$count ${count == 1 ? 'entrada' : 'entradas'}', style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
        AnimatedCount(money(total), duration: const Duration(milliseconds: 350), style: ts(AppTextSize.h3, w: FontWeight.w800, c: AppColors.accentPrimary)),
      ]),
      const SizedBox(width: 16),
      Expanded(child: PButton('Continuar', onPressed: count == 0 ? null : () => _next(e))),
    ]);

    return Scaffold(
      appBar: AppBar(title: Text('Elige tus entradas', style: ts(AppTextSize.bodyLg, w: FontWeight.w700))),
      bottomNavigationBar: wide ? null : BottomActionBar(maxWidth: 1000, child: bar),
      body: ResponsiveBody(
        maxWidth: 1000,
        child: wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 6, child: selector),
                const SizedBox(width: 24),
                Expanded(flex: 4, child: summary),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.name, style: ts(AppTextSize.body, c: AppColors.textSecondary)),
                const SizedBox(height: 10),
                selector,
              ]),
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
        Pressable(
          enabled: value > 0,
          pressedScale: 0.88,
          child: IconButton.outlined(
            onPressed: value > 0 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove),
            tooltip: 'Quitar una',
          ),
        ),
        SizedBox(
          width: 36,
          child: Center(
            child: AnimatedSwitcher(
              duration: Motion.fast,
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: ScaleTransition(scale: Tween<double>(begin: 0.6, end: 1).animate(a), child: child),
              ),
              child: Text('$value', key: ValueKey(value), style: ts(AppTextSize.bodyLg, w: FontWeight.w700, c: value > 0 ? AppColors.accentPrimary : AppColors.textPrimary)),
            ),
          ),
        ),
        Pressable(
          enabled: value < max,
          pressedScale: 0.88,
          child: IconButton.outlined(
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add),
            tooltip: 'Agregar una',
          ),
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
    // Cierra el flujo de compra y abre el pago como ventana emergente sobre
    // el listado de eventos.
    final nav = Navigator.of(context);
    nav.popUntil((r) => r.settings.arguments != _flow);
    showOrderDialog(nav.context, o.id);
  }

  @override
  Widget build(BuildContext context) {
    final e = _store.eventById(widget.eventId);
    final wide = _wide(context);
    final total = widget.qty.entries.fold<double>(0, (s, en) => s + en.value * e.types.firstWhere((t) => t.id == en.key).price);
    final n = widget.qty.values.fold(0, (a, b) => a + b);
    final pay = PButton('Continuar al pago', loading: _busy, onPressed: _submit);

    final fields = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FieldPair(
        stacked: wide,
        gap: wide ? 16 : AppSpacing.s3,
        a: TextFormField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Nombre completo *'),
          validator: (v) => (v == null || v.trim().split(' ').where((p) => p.isNotEmpty).length < 2) ? 'Ingresa nombre y apellido' : null,
        ),
        b: TextFormField(
          controller: _ci,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Número de CI *', hintText: 'Ej. 8123456 LP'),
          validator: (v) => RegExp(r'^\d{5,9}(\s?[A-Za-z]{1,3})?$').hasMatch((v ?? '').trim()) ? null : 'CI no válido',
        ),
      ),
      SizedBox(height: wide ? 16 : 12),
      FieldPair(
        stacked: wide,
        gap: wide ? 16 : AppSpacing.s3,
        a: TextFormField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Celular *', prefixText: '+591 '),
          validator: (v) => RegExp(r'^[67]\d{7}$').hasMatch((v ?? '').replaceAll(' ', '')) ? null : 'Celular de 8 dígitos que empiece con 6 o 7',
        ),
        b: TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          decoration: const InputDecoration(labelText: 'Correo (opcional)'),
          validator: (v) => (v == null || v.trim().isEmpty || v.contains('@')) ? null : 'Correo no válido',
        ),
      ),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.lock_outline, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text('Sin cuenta ni contraseña. Si agregas tu correo, también te enviamos las entradas cuando se confirme el pago.',
              style: ts(AppTextSize.caption, c: AppColors.textSecondary, h: 1.4)),
        ),
      ]),
    ]);

    // Resumen: una línea en celular; tarjeta lateral con el botón en pantallas anchas.
    final summaryLine = PCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: AppSpacing.s3),
      child: Row(children: [
        Expanded(child: Text('${e.name} · $n ${n == 1 ? 'entrada' : 'entradas'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(AppTextSize.body))),
        Text(money(total), style: ts(AppTextSize.bodyLg, w: FontWeight.w700, c: AppColors.accentPrimary)),
      ]),
    );
    final summaryCard = PCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Cover(e.hue, height: 90),
        const SizedBox(height: 12),
        Text(e.name, style: ts(AppTextSize.h3, w: FontWeight.w700)),
        Text('${fmtDateTime(e.date)} · ${e.place}', style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
        const Divider(height: 24),
        for (final en in widget.qty.entries)
          if (en.value > 0) KV('${en.value} × ${e.types.firstWhere((t) => t.id == en.key).name}', money(en.value * e.types.firstWhere((t) => t.id == en.key).price)),
        const Divider(height: 24),
        Row(children: [
          Expanded(child: Text('Total', style: ts(AppTextSize.bodyLg, w: FontWeight.w700))),
          Text(money(total), style: ts(AppTextSize.h3, w: FontWeight.w800, c: AppColors.accentPrimary)),
        ]),
        const SizedBox(height: 16),
        pay,
      ]),
    );

    return Scaffold(
      appBar: AppBar(title: Text('Tus datos', style: ts(AppTextSize.bodyLg, w: FontWeight.w700))),
      bottomNavigationBar: wide ? null : BottomActionBar(maxWidth: 640, child: pay),
      body: ResponsiveBody(
        maxWidth: wide ? 1000 : 640,
        child: Form(
          key: _form,
          child: wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    flex: 6,
                    child: Reveal(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('¿A nombre de quién van las entradas?', style: ts(AppTextSize.h3, w: FontWeight.w700)),
                        const SizedBox(height: 16),
                        fields,
                      ]),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(flex: 4, child: Reveal(delay: const Duration(milliseconds: 100), child: summaryCard)),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Reveal(child: summaryLine),
                  const SizedBox(height: 16),
                  Reveal(delay: const Duration(milliseconds: 80), child: fields),
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
        // Cada cambio de estado (pago avisado → verificando → aprobado) se
        // funde con el anterior en lugar de cortarse.
        return AnimatedSwitcher(
          duration: Motion.slow,
          switchInCurve: Motion.enter,
          switchOutCurve: Curves.easeIn,
          layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(a), child: child),
          ),
          child: KeyedSubtree(key: ValueKey(o.status), child: body),
        );
      },
    );
  }
}

/// Indica que el pedido se muestra dentro de la ventana emergente.
class _InDialog extends InheritedWidget {
  const _InDialog({required super.child});
  static bool of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<_InDialog>() != null;
  @override
  bool updateShouldNotify(_InDialog old) => false;
}

/// Sale del pedido: cierra la ventana emergente o vuelve al inicio.
void _leave(BuildContext c) => _InDialog.of(c) ? Navigator.of(c).pop() : Navigator.of(c).popUntil((r) => r.isFirst);

/// Pago y seguimiento del pedido como ventana emergente (no otra pantalla).
Future<void> showOrderDialog(BuildContext context, String orderId) => showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Pedido',
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: Motion.slow,
      pageBuilder: (ctx, _, _) {
        final size = MediaQuery.sizeOf(ctx);
        final mobile = size.width < Bp.tablet;
        return SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(mobile ? 8 : 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 1000, maxHeight: size.height - (mobile ? 16 : 48)),
                child: Material(
                  color: AppColors.bgPrimary,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.modal), side: const BorderSide(color: AppColors.bgBorder)),
                  child: SizedBox(
                    width: double.infinity,
                    height: size.height,
                    child: _InDialog(child: OrderScreen(orderId)),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, a, _, child) {
        if (Motion.reduced(ctx)) return child;
        final c = CurvedAnimation(parent: a, curve: Motion.enter, reverseCurve: Motion.exit);
        return FadeTransition(
          opacity: c,
          child: ScaleTransition(scale: Tween<double>(begin: 0.94, end: 1).animate(c), child: child),
        );
      },
    );

/// Marco común de cada estado del pedido: barra superior, cuerpo con scroll
/// de respaldo y (opcional) barra de acción fija al pie.
Widget _orderScaffold(BuildContext context, Order o, {required Widget body, Widget? bar, double maxWidth = 640}) => Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        automaticallyImplyLeading: !_InDialog.of(context),
        leading: _InDialog.of(context) ? IconButton(tooltip: 'Cerrar', icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()) : null,
        title: Text('Pedido ${o.number}', style: ts(AppTextSize.bodyLg, w: FontWeight.w700)),
      ),
      bottomNavigationBar: bar == null ? null : BottomActionBar(maxWidth: maxWidth, child: bar),
      body: ResponsiveBody(maxWidth: maxWidth, child: body),
    );

/// Resumen del pedido en una línea (evento, cantidad, total).
Widget _summaryCompact(Order o) {
  final e = _store.eventById(o.eventId);
  return PCard(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: AppSpacing.s3),
    child: Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(AppTextSize.body, w: FontWeight.w700)),
          Text('${o.ticketCount} ${o.ticketCount == 1 ? 'entrada' : 'entradas'} · ${fmtDateTime(e.date)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
        ]),
      ),
      const SizedBox(width: 12),
      Text(money(o.total), style: ts(AppTextSize.bodyLg, w: FontWeight.w800, c: AppColors.accentPrimary)),
    ]),
  );
}

Widget _summary(Order o) {
  final e = _store.eventById(o.eventId);
  return PCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(e.name, style: ts(AppTextSize.h3, w: FontWeight.w700)),
      Text('${fmtDateTime(e.date)} · ${e.place}', style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
      const Divider(height: 20),
      for (final l in o.lines) KV('${l.qty} × ${e.types.firstWhere((t) => t.id == l.typeId).name}', money(l.qty * e.types.firstWhere((t) => t.id == l.typeId).price)),
      const Divider(height: 20),
      Row(children: [
        Expanded(child: Text('Total', style: ts(AppTextSize.bodyLg, w: FontWeight.w700))),
        Text(money(o.total), style: ts(AppTextSize.h3, w: FontWeight.w800, c: AppColors.accentPrimary)),
      ]),
    ]),
  );
}

/// Enlace privado en una fila, con botón para copiarlo.
Widget _privateLink(BuildContext context, Order o) {
  final link = 'check.app/pedido/${o.token}';
  return PCard(
    padding: const EdgeInsets.fromLTRB(AppSpacing.s4, AppSpacing.s3, AppSpacing.s2, AppSpacing.s3),
    child: Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tu enlace privado', style: ts(AppTextSize.caption, c: AppColors.textSecondary, w: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(link, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(AppTextSize.body, c: AppColors.accentPrimary)),
          const SizedBox(height: 2),
          Text('Guárdalo: es la única forma de volver a ver tu pedido.', style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
        ]),
      ),
      IconButton(
        tooltip: 'Copiar enlace',
        icon: const Icon(Icons.copy_rounded, size: 20),
        onPressed: () {
          Clipboard.setData(ClipboardData(text: link));
          toast(context, 'Enlace copiado');
        },
      ),
    ]),
  );
}

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

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: const Text('¿Cancelar el pedido?'),
        content: const Text('Se liberarán tus entradas reservadas.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Volver')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sí, cancelar'))],
      ),
    );
    if (ok == true) _store.cancelOrder(widget.o.id);
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.o;
    final wide = _wide(context);
    final left = o.expiresAt.difference(DateTime.now());
    final s = left.isNegative ? 0 : left.inSeconds;
    final clock = '${two(s ~/ 60)}:${two(s % 60)}';
    final urgent = s < 180;
    final tone = urgent ? AppColors.error : PColors.warning;

    final timer = PCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: AppSpacing.s3),
      color: tone.withValues(alpha: 0.10),
      border: tone.withValues(alpha: 0.5),
      child: Row(children: [
        Icon(Icons.timer_outlined, color: tone),
        const SizedBox(width: 12),
        Expanded(child: Text('Tiempo para pagar y avisar', style: ts(AppTextSize.body))),
        Text(clock, style: ts(24, w: FontWeight.w800, c: tone)),
      ]),
    );

    final qr = PCard(
      child: Column(children: [
        Text('Paga con el QR bancario del local', style: ts(AppTextSize.body, w: FontWeight.w700), textAlign: TextAlign.center),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.sm)),
          child: QrImageView(data: 'DEMO-QR-BANCARIO-NO-VALIDO-${o.number}', size: wide ? 190 : 160, backgroundColor: Colors.white),
        ),
        const SizedBox(height: 8),
        const Chip2('QR de demostración · no válido para pagar', PColors.warning),
        const SizedBox(height: 8),
        KV('Beneficiario', ProtoStore.bankBeneficiary),
        KV('Monto a pagar', money(o.total)),
      ]),
    );

    final steps = ['Abre la app de tu banco y escanea el QR.', 'Paga exactamente ${money(o.total)}.', 'Vuelve aquí y pulsa «Ya pagué».'];

    if (wide) {
      return _orderScaffold(
        context,
        o,
        maxWidth: 960,
        body: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 5, child: Reveal(child: qr)),
          const SizedBox(width: 24),
          Expanded(
            flex: 5,
            child: Reveal(
              delay: const Duration(milliseconds: 90),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                timer,
                const SizedBox(height: 12),
                _summary(o),
                const SizedBox(height: 12),
                PCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Instrucciones', style: ts(AppTextSize.body, w: FontWeight.w700)),
                    const SizedBox(height: 6),
                    for (final (i, t) in steps.indexed) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('${i + 1}. $t', style: ts(AppTextSize.body, c: AppColors.textSecondary))),
                  ]),
                ),
                const SizedBox(height: 16),
                PButton('Ya pagué', icon: Icons.check, onPressed: () => _store.declarePaid(o.id)),
                const SizedBox(height: 8),
                PButton('Cancelar pedido', kind: BtnKind.secondary, onPressed: _cancel),
              ]),
            ),
          ),
        ]),
      );
    }

    return _orderScaffold(
      context,
      o,
      bar: Row(children: [
        TextButton(onPressed: _cancel, child: const Text('Cancelar')),
        const SizedBox(width: 8),
        Expanded(child: PButton('Ya pagué', icon: Icons.check, onPressed: () => _store.declarePaid(o.id))),
      ]),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        timer,
        const SizedBox(height: 10),
        _summaryCompact(o),
        const SizedBox(height: 10),
        Reveal(delay: const Duration(milliseconds: 90), child: qr),
        const SizedBox(height: 10),
        Text('1 Escanea el QR en tu banco · 2 Paga el monto exacto · 3 Pulsa «Ya pagué»',
            textAlign: TextAlign.center, style: ts(AppTextSize.caption, c: AppColors.textSecondary, h: 1.4)),
      ]),
    );
  }
}

// B2
class _Verifying extends StatelessWidget {
  const _Verifying(this.o);
  final Order o;
  @override
  Widget build(BuildContext context) {
    final wide = _wide(context);
    final head = Column(children: [
      const SizedBox(
        width: 44,
        height: 44,
        child: CircularProgressIndicator(color: PColors.warning, strokeWidth: 4),
      ),
      const SizedBox(height: 12),
      Text('Estamos verificando tu pago', style: ts(AppTextSize.h2, w: FontWeight.w800), textAlign: TextAlign.center),
      const SizedBox(height: 2),
      Text('Pedido ${o.number}', style: ts(AppTextSize.body, c: AppColors.textSecondary)),
    ]);
    const notice = Notice('Informaste tu pago. El local debe comprobar el depósito en su cuenta bancaria. Todavía no se ha confirmado que lo recibió y tus entradas aún no están habilitadas.');
    final foot = Text('Esta pantalla se actualiza sola cuando el local decida.', textAlign: TextAlign.center, style: ts(AppTextSize.caption, c: AppColors.textSecondary));

    return _orderScaffold(
      context,
      o,
      maxWidth: wide ? 900 : 640,
      body: wide
          ? Column(children: [
              Reveal(scale: 0.96, child: head),
              const SizedBox(height: 20),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Reveal(delay: const Duration(milliseconds: 90), child: _summary(o))),
                const SizedBox(width: 24),
                Expanded(
                  child: Reveal(
                    delay: const Duration(milliseconds: 150),
                    child: Column(children: [notice, const SizedBox(height: 12), _privateLink(context, o)]),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              foot,
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Reveal(scale: 0.96, child: head),
              const SizedBox(height: 16),
              Reveal(delay: const Duration(milliseconds: 80), child: notice),
              const SizedBox(height: 10),
              Reveal(delay: const Duration(milliseconds: 140), child: _summaryCompact(o)),
              const SizedBox(height: 10),
              Reveal(delay: const Duration(milliseconds: 200), child: _privateLink(context, o)),
              const SizedBox(height: 12),
              foot,
            ]),
    );
  }
}

// B5
class _Approved extends StatelessWidget {
  const _Approved(this.o);
  final Order o;
  @override
  Widget build(BuildContext context) {
    final e = _store.eventById(o.eventId);
    final wide = _wide(context);

    final header = Row(mainAxisSize: MainAxisSize.min, children: [
      const Reveal(scale: 0.4, dy: 0, curve: Motion.pop, duration: Duration(milliseconds: 550), child: Icon(Icons.check_circle, color: AppColors.success, size: 44)),
      const SizedBox(width: 12),
      Flexible(
        child: Reveal(
          delay: const Duration(milliseconds: 120),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Pago aprobado', style: ts(AppTextSize.h2, w: FontWeight.w800)),
            Text('${o.ticketCount} ${o.ticketCount == 1 ? 'entrada' : 'entradas'} · ${e.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(AppTextSize.body, c: AppColors.textSecondary)),
          ]),
        ),
      ),
    ]);
    const warning = Reveal(
      delay: Duration(milliseconds: 200),
      child: Notice(
        'Cuida tu código QR y no lo compartas con otras personas. Cada QR permite un único ingreso. Si alguien lo utiliza antes que tú, podría impedirte el acceso al evento.',
        color: AppColors.error,
        icon: Icons.warning_amber_rounded,
      ),
    );
    final mail = o.email == null ? null : Notice('También enviaremos tus entradas a ${o.email} (simulado).', color: AppColors.success, icon: Icons.mail_outline);
    final link = Reveal(delay: const Duration(milliseconds: 320), child: _privateLink(context, o));
    final tickets = Reveal(delay: const Duration(milliseconds: 260), child: _TicketCarousel(o));

    return _orderScaffold(
      context,
      o,
      maxWidth: wide ? 960 : 720,
      body: wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 5,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  header,
                  const SizedBox(height: 14),
                  warning,
                  if (mail != null) ...[const SizedBox(height: 8), mail],
                  const SizedBox(height: 10),
                  link,
                ]),
              ),
              const SizedBox(width: 24),
              Expanded(flex: 5, child: tickets),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              header,
              const SizedBox(height: 12),
              warning,
              const SizedBox(height: 12),
              tickets,
              if (mail != null) ...[const SizedBox(height: 8), mail],
              const SizedBox(height: 10),
              link,
            ]),
    );
  }
}

/// Una entrada a la vez (se desliza o se navega con flechas) en celular;
/// cuadrícula si hay espacio. Altura natural: nunca recorta el QR.
class _TicketCarousel extends StatefulWidget {
  const _TicketCarousel(this.o);
  final Order o;
  @override
  State<_TicketCarousel> createState() => _TicketCarouselState();
}

class _TicketCarouselState extends State<_TicketCarousel> {
  int _i = 0;
  int _dir = 1; // 1 = avanza (entra desde la derecha), -1 = retrocede

  void _go(int i, int n) {
    if (i < 0 || i >= n || i == _i) return;
    setState(() {
      _dir = i > _i ? 1 : -1;
      _i = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.o;
    final n = o.ticketCodes.length;
    return LayoutBuilder(builder: (context, c) {
      if (n > 1 && c.maxWidth >= 560) {
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (var i = 0; i < n; i++) SizedBox(width: (c.maxWidth - 12) / 2, child: _TicketCard(o, i)),
        ]);
      }
      return Column(children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -200) _go(_i + 1, n);
            if (v > 200) _go(_i - 1, n);
          },
          child: AnimatedSize(
            duration: Motion.base,
            curve: Motion.enter,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: Motion.base,
              switchInCurve: Motion.enter,
              layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
              transitionBuilder: (child, a) {
                final incoming = child.key == ValueKey(_i);
                return FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: Offset((incoming ? _dir : -_dir) * 0.2, 0), end: Offset.zero).animate(a),
                    child: child,
                  ),
                );
              },
              child: SizedBox(key: ValueKey(_i), width: double.infinity, child: _TicketCard(o, _i)),
            ),
          ),
        ),
        if (n > 1)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(tooltip: 'Anterior', onPressed: _i > 0 ? () => _go(_i - 1, n) : null, icon: const Icon(Icons.chevron_left)),
              for (var i = 0; i < n; i++)
                AnimatedContainer(
                  duration: Motion.base,
                  curve: Motion.enter,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _i ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(color: i == _i ? AppColors.accentPrimary : AppColors.bgBorder, borderRadius: BorderRadius.circular(AppRadius.full)),
                ),
              IconButton(tooltip: 'Siguiente', onPressed: _i < n - 1 ? () => _go(_i + 1, n) : null, icon: const Icon(Icons.chevron_right)),
            ]),
          ),
      ]);
    });
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
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: Text('Entrada ${i + 1} de ${o.ticketCount}', style: ts(AppTextSize.body, w: FontWeight.w700))),
          const Chip2('Demo · no válida', PColors.warning),
        ]),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.sm)),
          child: QrImageView(data: 'INVALID-DEMO-$code', size: 140, backgroundColor: Colors.white),
        ),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(child: Text(code, style: ts(AppTextSize.caption, c: AppColors.textSecondary))),
          TextButton.icon(
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2), minimumSize: const Size(0, 32), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            onPressed: () => toast(context, 'Descarga simulada de $code'),
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Descargar QR'),
          ),
        ]),
        Text('QR de demostración · no válido en ningún evento', textAlign: TextAlign.center, style: ts(AppTextSize.caption, w: FontWeight.w700, c: PColors.warning)),
      ]),
    );
  }
}

// B6
class _Rejected extends StatelessWidget {
  const _Rejected(this.o);
  final Order o;
  @override
  Widget build(BuildContext context) => _orderScaffold(
        context,
        o,
        bar: PButton('Ver otros eventos', kind: BtnKind.secondary, onPressed: () => _leave(context)),
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: Column(children: [
              const Reveal(scale: 0.5, dy: 0, curve: Motion.pop, duration: Duration(milliseconds: 500), child: Icon(Icons.cancel, color: AppColors.error, size: 48)),
              const SizedBox(height: 6),
              Text('Pago rechazado', style: ts(AppTextSize.h2, w: FontWeight.w800)),
            ]),
          ),
          const SizedBox(height: 14),
          Notice('El local no pudo confirmar tu depósito.${o.rejectReason == null ? '' : ' Motivo: ${o.rejectReason}'}', color: AppColors.error, icon: Icons.info_outline),
          const SizedBox(height: 8),
          const Notice('Esta decisión es definitiva: el pedido no se puede reactivar y tus cupos fueron liberados. Si crees que es un error, comunícate con el local.'),
          const SizedBox(height: 12),
          _summaryCompact(o),
        ]),
      );
}

class _Closed extends StatelessWidget {
  const _Closed(this.o);
  final Order o;
  @override
  Widget build(BuildContext context) => _orderScaffold(
        context,
        o,
        bar: PButton('Volver a eventos', onPressed: () => _leave(context)),
        body: StateView(ViewState.empty, message: o.status == OrderStatus.expired ? 'El tiempo para pagar terminó y las entradas se liberaron.' : 'Cancelaste este pedido.'),
      );
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
        bottomNavigationBar: BottomActionBar(maxWidth: 520, child: PButton('Ver pedido', onPressed: _go)),
        body: ResponsiveBody(
          maxWidth: 520,
          child: Reveal(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const H('Abre tu enlace privado', sub: 'Pega el código de tu enlace (o el número de pedido). No necesitas iniciar sesión.'),
              TextField(controller: _c, onSubmitted: (_) => _go(), decoration: InputDecoration(labelText: 'Código o número de pedido', errorText: _err)),
              const SizedBox(height: 16),
              Text('Para probar, usa un pedido de ejemplo:', style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                for (final o in _store.orders.take(5)) ActionChip(label: Text(o.number), onPressed: () => setState(() => _c.text = o.number)),
              ]),
            ]),
          ),
        ),
      );
}
