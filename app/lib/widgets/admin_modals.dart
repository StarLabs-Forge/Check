import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/admin_repository.dart';
import '../data/models.dart';
import '../services/errors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// Modales del panel Admin (Figma "Modal" — tipos "Crear evento" y
/// "Generar tickets"): tarjeta de 520px sobre overlay 80% negro, header con
/// título + botón de cerrar, cuerpo con campos, footer con Cancelar +
/// acción primaria. Persisten en Supabase vía [AdminRepository].

/// Devuelve `true` si se creó un evento.
Future<bool?> showCreateEventModal(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.8),
    builder: (_) => const _ModalShell(title: 'Nuevo evento', child: _CreateEventForm()),
  );
}

/// Devuelve `true` si se emitió al menos un ticket.
Future<bool?> showGenerateTicketsModal(BuildContext context, {required EventItem event}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.8),
    builder: (_) => _ModalShell(
      title: 'Generar nuevos tickets',
      child: _GenerateTicketsForm(event: event),
    ),
  );
}

class _ModalShell extends StatelessWidget {
  const _ModalShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.s6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s6),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            border: Border.all(color: AppColors.bgBorder),
            borderRadius: BorderRadius.circular(AppRadius.modal),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.h2, fontWeight: FontWeight.w700),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, color: AppColors.textSecondary, size: 22),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s6),
                const Divider(height: 1, color: AppColors.bgBorder),
                const SizedBox(height: AppSpacing.s6),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s2),
      child: Text(
        label,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.caption, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s4),
      child: Text(message, style: const TextStyle(color: AppColors.error, fontSize: AppTextSize.caption)),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.bgPrimary),
      );
}

/// Botón de opción tipo "segmento" (Un invitado / CSV, Gratis / De pago).
class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.label, required this.selected, required this.onPressed});

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? AppColors.accentPrimary : AppColors.textSecondary,
        side: BorderSide(color: selected ? AppColors.accentPrimary : AppColors.bgBorder),
      ),
      child: Text(label),
    );
  }
}

// ───────────────────────── Crear evento ─────────────────────────

class _CreateEventForm extends StatefulWidget {
  const _CreateEventForm();

  @override
  State<_CreateEventForm> createState() => _CreateEventFormState();
}

class _CreateEventFormState extends State<_CreateEventForm> {
  final _nameCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  DateTime? _date; // fecha local (La Paz), sin hora
  TimeOfDay? _start;
  TimeOfDay? _end;
  bool _paid = false;

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _capacityCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickStart() async {
    final picked = await showTimePicker(context: context, initialTime: _start ?? const TimeOfDay(hour: 22, minute: 0));
    if (picked == null) return;
    setState(() {
      _start = picked;
      // Sugerencia: termina 4 h después (los eventos nocturnos cruzan medianoche).
      _end ??= TimeOfDay(hour: (picked.hour + 4) % 24, minute: picked.minute);
    });
  }

  Future<void> _pickEnd() async {
    final picked = await showTimePicker(context: context, initialTime: _end ?? const TimeOfDay(hour: 2, minute: 0));
    if (picked != null) setState(() => _end = picked);
  }

  String? _validate() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return 'Ingresa el nombre del evento.';
    if (name.length > 120) return 'El nombre es muy largo (máx. 120).';
    if (_date == null) return 'Elige la fecha.';
    if (_start == null) return 'Elige la hora de inicio.';
    if (_end == null) return 'Elige la hora de fin.';
    final cap = int.tryParse(_capacityCtrl.text.trim());
    if (cap == null || cap <= 0) return 'La capacidad debe ser un número mayor a 0.';
    if (_paid) {
      final price = double.tryParse(_priceCtrl.text.trim().replaceAll(',', '.'));
      if (price == null || price <= 0) return 'Ingresa un precio válido para el ticket.';
    }
    if (_descCtrl.text.trim().length > 2000) return 'La descripción es muy larga (máx. 2000).';
    return null;
  }

  Future<void> _submit() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    final d = _date!;
    final startsAt = Fmt.fromLaPaz(d.year, d.month, d.day, _start!.hour, _start!.minute);
    var endsAt = Fmt.fromLaPaz(d.year, d.month, d.day, _end!.hour, _end!.minute);
    // Si la hora de fin no es posterior a la de inicio, termina al día siguiente.
    if (!endsAt.isAfter(startsAt)) endsAt = endsAt.add(const Duration(days: 1));

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await AdminRepository.instance.createEvent(
        name: _nameCtrl.text,
        description: _descCtrl.text,
        startsAt: startsAt,
        endsAt: endsAt,
        capacity: int.parse(_capacityCtrl.text.trim()),
        paid: _paid,
        price: _paid ? double.parse(_priceCtrl.text.trim().replaceAll(',', '.')) : 0,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evento creado como borrador. Actívalo cuando esté listo.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _FieldLabel('Nombre'),
        TextField(controller: _nameCtrl, decoration: const InputDecoration(hintText: 'Ej: Eclipse Party')),
        const SizedBox(height: AppSpacing.s4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('Fecha'),
                  _PickerField(
                    text: _date == null ? null : Fmt.dmy(_date!),
                    hint: 'dd/mm/aaaa',
                    icon: Icons.calendar_today_outlined,
                    onTap: _pickDate,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('Inicio'),
                  _PickerField(
                    text: _start == null ? null : Fmt.hm(_start!.hour, _start!.minute),
                    hint: '22:00',
                    icon: Icons.schedule,
                    onTap: _pickStart,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('Fin'),
                  _PickerField(
                    text: _end == null ? null : Fmt.hm(_end!.hour, _end!.minute),
                    hint: '02:00',
                    icon: Icons.schedule,
                    onTap: _pickEnd,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s4),
        const _FieldLabel('Capacidad'),
        TextField(
          controller: _capacityCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(hintText: 'Ej: 200'),
        ),
        const SizedBox(height: AppSpacing.s4),
        const _FieldLabel('Acceso'),
        Row(
          children: [
            Expanded(child: _ModeButton(label: 'Gratis', selected: !_paid, onPressed: () => setState(() => _paid = false))),
            const SizedBox(width: AppSpacing.s3),
            Expanded(child: _ModeButton(label: 'De pago', selected: _paid, onPressed: () => setState(() => _paid = true))),
          ],
        ),
        if (_paid) ...[
          const SizedBox(height: AppSpacing.s4),
          const _FieldLabel('Precio del ticket (Bs.)'),
          TextField(
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'Ej: 50'),
          ),
        ],
        const SizedBox(height: AppSpacing.s4),
        const _FieldLabel('Descripción (opcional)'),
        TextField(controller: _descCtrl, decoration: const InputDecoration(hintText: 'Una noche de música y encuentros.')),
        if (_error != null) _ErrorText(_error!),
        const SizedBox(height: AppSpacing.s6),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: _submitting ? null : () => Navigator.of(context).pop(), child: const Text('Cancelar')),
            const SizedBox(width: AppSpacing.s3),
            SizedBox(
              width: 180,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting ? const _Spinner() : const Text('Crear evento'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Campo de solo lectura que abre un selector (fecha/hora) al tocarlo.
class _PickerField extends StatelessWidget {
  const _PickerField({required this.text, required this.hint, required this.icon, required this.onTap});

  final String? text;
  final String hint;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: InputDecorator(
        decoration: InputDecoration(
          hintText: hint,
          suffixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
        ),
        isEmpty: text == null,
        child: Text(
          text ?? '',
          style: const TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.body),
        ),
      ),
    );
  }
}

// ───────────────────────── Generar tickets ─────────────────────────

class _GenerateTicketsForm extends StatefulWidget {
  const _GenerateTicketsForm({required this.event});

  final EventItem event;

  @override
  State<_GenerateTicketsForm> createState() => _GenerateTicketsFormState();
}

enum _LoadMode { single, csv }

class _GenerateTicketsFormState extends State<_GenerateTicketsForm> {
  _LoadMode _mode = _LoadMode.single;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _alreadyPaid = false;
  bool _submitting = false;
  String? _error;

  /// Último ticket emitido: se muestra su QR (el token no se puede recuperar).
  CreatedTicket? _created;
  String _createdName = '';
  bool _issuedAny = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Ingresa el nombre del invitado.');
      return;
    }
    if (name.length > 120) {
      setState(() => _error = 'El nombre es muy largo (máx. 120).');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final ticket = await AdminRepository.instance.createTicket(
        eventId: widget.event.id,
        guestName: name,
        guestPhone: _phoneCtrl.text,
        paid: widget.event.isPaid && _alreadyPaid,
      );
      if (!mounted) return;
      setState(() {
        _created = ticket;
        _createdName = name;
        _issuedAny = true;
        _submitting = false;
        _nameCtrl.clear();
        _phoneCtrl.clear();
        _alreadyPaid = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final created = _created;
    if (created != null) {
      return _TicketCreatedView(
        guestName: _createdName,
        eventName: widget.event.name,
        ticket: created,
        onAnother: () => setState(() => _created = null),
        onDone: () => Navigator.of(context).pop(_issuedAny),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.event.name,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
        ),
        const SizedBox(height: AppSpacing.s4),
        Row(
          children: [
            Expanded(
              child: _ModeButton(
                label: 'Un invitado',
                selected: _mode == _LoadMode.single,
                onPressed: () => setState(() => _mode = _LoadMode.single),
              ),
            ),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: _ModeButton(
                label: 'Carga masiva CSV',
                selected: _mode == _LoadMode.csv,
                onPressed: () => setState(() => _mode = _LoadMode.csv),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s5),
        if (_mode == _LoadMode.single) ...[
          const _FieldLabel('Nombre del invitado'),
          TextField(controller: _nameCtrl, decoration: const InputDecoration(hintText: 'Ej: Valentina Quispe')),
          const SizedBox(height: AppSpacing.s4),
          const _FieldLabel('Teléfono (opcional)'),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(hintText: 'Ej: 70012345'),
          ),
          if (widget.event.isPaid) ...[
            const SizedBox(height: AppSpacing.s4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Ya pagó (${Fmt.money(widget.event.ticketPrice)})',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.body),
                  ),
                ),
                Switch(
                  value: _alreadyPaid,
                  activeThumbColor: AppColors.accentPrimary,
                  onChanged: (v) => setState(() => _alreadyPaid = v),
                ),
              ],
            ),
            const Text(
              'Si no pagó, el staff cobra en puerta al escanear.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.caption),
            ),
          ],
        ] else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.s5),
            decoration: BoxDecoration(
              color: AppColors.bgInput,
              border: Border.all(color: AppColors.bgBorder),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Column(
              children: [
                Icon(Icons.upload_outlined, color: AppColors.textSecondary, size: 24),
                SizedBox(height: AppSpacing.s3),
                Text(
                  'La carga masiva por CSV llega en una próxima versión.\nPor ahora emite los tickets de a uno.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
                ),
              ],
            ),
          ),
        if (_error != null) _ErrorText(_error!),
        const SizedBox(height: AppSpacing.s6),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _submitting ? null : () => Navigator.of(context).pop(_issuedAny),
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: AppSpacing.s3),
            SizedBox(
              width: 180,
              child: ElevatedButton(
                onPressed: (_submitting || _mode == _LoadMode.csv) ? null : _submit,
                child: _submitting ? const _Spinner() : const Text('Generar ticket'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Vista de "ticket emitido": QR + código para copiar. El token solo existe
/// acá (en la base queda únicamente su hash), así que se avisa al usuario que
/// lo comparta/guarde ahora.
class _TicketCreatedView extends StatelessWidget {
  const _TicketCreatedView({
    required this.guestName,
    required this.eventName,
    required this.ticket,
    required this.onAnother,
    required this.onDone,
  });

  final String guestName;
  final String eventName;
  final CreatedTicket ticket;
  final VoidCallback onAnother;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final paid = ticket.paymentStatus == 'paid';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          guestName,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.h3, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.s1),
        Text(
          '$eventName · ${paid ? 'Pagado' : 'Por cobrar en puerta'}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
        ),
        const SizedBox(height: AppSpacing.s5),
        Center(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.s3),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: QrImageView(
              data: ticket.qrToken,
              size: 200,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        const Text(
          'Comparte o guarda este QR ahora: por seguridad no se puede volver a mostrar.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.caption),
        ),
        const SizedBox(height: AppSpacing.s4),
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: ticket.qrToken));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código copiado')));
            }
          },
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('Copiar código'),
        ),
        const SizedBox(height: AppSpacing.s6),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: onAnother, child: const Text('Emitir otro')),
            const SizedBox(width: AppSpacing.s3),
            SizedBox(width: 140, child: ElevatedButton(onPressed: onDone, child: const Text('Listo'))),
          ],
        ),
      ],
    );
  }
}
