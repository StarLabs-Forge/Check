import 'package:flutter/material.dart';

import '../config/demo_mode.dart';
import '../data/admin_repository.dart';
import '../services/errors.dart';
import '../theme/app_theme.dart';

/// Gestión de categorías de entrada de un evento (panel del local).
/// La lógica transaccional (precios, cupos, reservas) vive en la base:
/// acá solo se editan filas de `ticket_types` y se muestran sus cifras.
class TicketCategoriesSection extends StatefulWidget {
  const TicketCategoriesSection({super.key, required this.eventId, this.locked = false});

  final String eventId;

  /// Evento finalizado o suspendido: solo lectura.
  final bool locked;

  @override
  State<TicketCategoriesSection> createState() => _TicketCategoriesSectionState();
}

class _TicketCategoriesSectionState extends State<TicketCategoriesSection> {
  final _repo = AdminRepository.instance;
  List<TicketCategory>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _repo.listCategories(widget.eventId);
      if (mounted) setState(() { _items = items; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _toggle(TicketCategory c) async {
    try {
      await _repo.saveCategory(
        id: c.id, eventId: widget.eventId, name: c.name, description: c.description,
        price: c.price, capacity: c.capacity, maxPerOrder: c.maxPerOrder, active: !c.active,
      );
      await _load();
    } catch (e) {
      if (mounted) _toast(friendlyError(e));
    }
  }

  Future<void> _delete(TicketCategory c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: const Text('¿Eliminar categoría?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('"${c.name}" se eliminará. Solo es posible si no tiene pedidos ni entradas.',
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteCategory(c.id);
      await _load();
    } catch (e) {
      if (mounted) _toast(friendlyError(e));
    }
  }

  Future<void> _edit([TicketCategory? c]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CategoryDialog(eventId: widget.eventId, category: c),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (kDemo) return const SizedBox.shrink();
    final items = _items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Expanded(
            child: Text('Categorías de entrada',
                style: TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.h3, fontWeight: FontWeight.w700)),
          ),
          if (!widget.locked) TextButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add, size: 18), label: const Text('Nueva categoría')),
        ]),
        const SizedBox(height: AppSpacing.s3),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: AppColors.error))
        else if (items == null)
          const Text('Cargando…', style: TextStyle(color: AppColors.textSecondary))
        else if (items.isEmpty)
          const Text('Este evento aún no tiene categorías.', style: TextStyle(color: AppColors.textSecondary))
        else
          for (final c in items) _row(c),
      ],
    );
  }

  Widget _row(TicketCategory c) {
    final stats = c.sold == null
        ? 'Cupo ${c.capacity}'
        : 'Vendidas ${c.sold} · Reservadas ${c.reserved} · Disponibles ${c.available} de ${c.capacity}';
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s3),
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border.all(color: AppColors.bgBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: AppSpacing.s2,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${c.name} · Bs ${c.price.toStringAsFixed(2)}${c.active ? '' : ' · Inactiva'}',
                  style: TextStyle(color: c.active ? AppColors.textPrimary : AppColors.textDisabled, fontWeight: FontWeight.w600)),
              if (c.description.isNotEmpty)
                Text(c.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.caption)),
              Text(stats, style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.caption)),
            ]),
          ),
          if (!widget.locked)
            Wrap(children: [
              TextButton(onPressed: () => _edit(c), child: const Text('Editar')),
              TextButton(onPressed: () => _toggle(c), child: Text(c.active ? 'Desactivar' : 'Activar')),
              if (!c.hasOperations)
                TextButton(
                  onPressed: () => _delete(c),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Eliminar'),
                ),
            ]),
        ],
      ),
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({required this.eventId, this.category});
  final String eventId;
  final TicketCategory? category;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.category?.name ?? '');
  late final _desc = TextEditingController(text: widget.category?.description ?? '');
  late final _price = TextEditingController(text: widget.category == null ? '' : '${widget.category!.price}');
  late final _cap = TextEditingController(text: widget.category == null ? '' : '${widget.category!.capacity}');
  late final _max = TextEditingController(text: '${widget.category?.maxPerOrder ?? 6}');
  late bool _active = widget.category?.active ?? true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _price.dispose();
    _cap.dispose();
    _max.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      await AdminRepository.instance.saveCategory(
        id: widget.category?.id,
        eventId: widget.eventId,
        name: _name.text,
        description: _desc.text,
        price: double.parse(_price.text.replaceAll(',', '.')),
        capacity: int.parse(_cap.text),
        maxPerOrder: int.parse(_max.text),
        active: _active,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _saving = false; });
    }
  }

  String? _int(String? v, int min, int max) {
    final n = int.tryParse(v ?? '');
    return (n == null || n < min || n > max) ? 'Entre $min y $max' : null;
  }

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: AppColors.textPrimary);
    return AlertDialog(
      backgroundColor: AppColors.bgSurface,
      title: Text(widget.category == null ? 'Nueva categoría' : 'Editar categoría', style: style),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: _name, style: style, maxLength: 60,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa un nombre' : null,
              ),
              TextFormField(
                controller: _desc, style: style, maxLength: 200,
                decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
              ),
              TextFormField(
                controller: _price, style: style,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Precio (Bs)', helperText: 'Solo afecta pedidos nuevos'),
                validator: (v) {
                  final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                  return (n == null || n < 0) ? 'Precio inválido' : null;
                },
              ),
              TextFormField(
                controller: _cap, style: style, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cupo'),
                validator: (v) => _int(v, 1, 1000000),
              ),
              TextFormField(
                controller: _max, style: style, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Máximo por pedido'),
                validator: (v) => _int(v, 1, 20),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Disponible para la venta', style: style),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
              if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.error)),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
        TextButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Guardando…' : 'Guardar')),
      ],
    );
  }
}
