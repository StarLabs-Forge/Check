import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Modales del panel Admin (Figma "Modal" — tipos "Crear evento" y
/// "Generar tickets"): tarjeta de 520px sobre overlay 80% negro, header con
/// título + botón de cerrar, cuerpo con campos, footer con Cancelar +
/// acción primaria. Solo UI — no persiste nada todavía (sin Supabase).

Future<void> showCreateEventModal(BuildContext context) {
  return showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.8),
    builder: (_) => const _ModalShell(title: 'Nuevo evento', child: _CreateEventForm()),
  );
}

Future<void> showGenerateTicketsModal(BuildContext context, {required String eventName}) {
  return showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.8),
    builder: (_) => _ModalShell(
      title: 'Generar nuevos tickets',
      child: _GenerateTicketsForm(eventName: eventName),
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

class _CreateEventForm extends StatefulWidget {
  const _CreateEventForm();

  @override
  State<_CreateEventForm> createState() => _CreateEventFormState();
}

class _CreateEventFormState extends State<_CreateEventForm> {
  final _nameCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    _capacityCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    // Solo-frontend: todavía no hay backend de Supabase conectado para
    // persistir el evento. Simulamos el éxito y cerramos el modal.
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Evento creado (simulado) — falta conectar Supabase')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _FieldLabel('Nombre'),
        TextField(controller: _nameCtrl, decoration: const InputDecoration(hintText: 'Ej: Eclipse Party')),
        const SizedBox(height: AppSpacing.s4),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel('Fecha'),
                  TextField(controller: _dateCtrl, decoration: const InputDecoration(hintText: 'dd/mm/aaaa')),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel('Hora inicio'),
                  TextField(controller: _timeCtrl, decoration: const InputDecoration(hintText: '22:00')),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s4),
        _FieldLabel('Capacidad'),
        TextField(
          controller: _capacityCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Ej: 200'),
        ),
        const SizedBox(height: AppSpacing.s4),
        _FieldLabel('Descripción (opcional)'),
        TextField(controller: _descCtrl, decoration: const InputDecoration(hintText: 'Una noche de música y encuentros.')),
        const SizedBox(height: AppSpacing.s6),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
            const SizedBox(width: AppSpacing.s3),
            SizedBox(
              width: 180,
              child: ElevatedButton(onPressed: _submit, child: const Text('Crear evento')),
            ),
          ],
        ),
      ],
    );
  }
}

class _GenerateTicketsForm extends StatefulWidget {
  const _GenerateTicketsForm({required this.eventName});

  final String eventName;

  @override
  State<_GenerateTicketsForm> createState() => _GenerateTicketsFormState();
}

enum _LoadMode { single, csv }

class _GenerateTicketsFormState extends State<_GenerateTicketsForm> {
  _LoadMode _mode = _LoadMode.single;
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ticket generado para ${widget.eventName} (simulado) — falta conectar Supabase')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _mode = _LoadMode.single),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _mode == _LoadMode.single ? AppColors.accentPrimary : AppColors.textSecondary,
                  side: BorderSide(color: _mode == _LoadMode.single ? AppColors.accentPrimary : AppColors.bgBorder),
                ),
                child: const Text('Un invitado'),
              ),
            ),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _mode = _LoadMode.csv),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _mode == _LoadMode.csv ? AppColors.accentPrimary : AppColors.textSecondary,
                  side: BorderSide(color: _mode == _LoadMode.csv ? AppColors.accentPrimary : AppColors.bgBorder),
                ),
                child: const Text('Carga masiva CSV'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s5),
        if (_mode == _LoadMode.single) ...[
          _FieldLabel('Nombre del invitado'),
          TextField(controller: _nameCtrl, decoration: const InputDecoration(hintText: 'Ej: Valentina Quispe')),
        ] else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.s5),
            decoration: BoxDecoration(
              color: AppColors.bgInput,
              border: Border.all(color: AppColors.bgBorder),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              children: [
                const Icon(Icons.upload_outlined, color: AppColors.textSecondary, size: 24),
                const SizedBox(height: AppSpacing.s3),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Selector de archivos pendiente de integrar')),
                    );
                  },
                  child: const Text('Cargar CSV con múltiples nombres'),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.s6),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
            const SizedBox(width: AppSpacing.s3),
            SizedBox(
              width: 180,
              child: ElevatedButton(onPressed: _submit, child: const Text('Generar ticket')),
            ),
          ],
        ),
      ],
    );
  }
}
