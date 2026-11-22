import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/admin_repository.dart';
import '../../data/models.dart' as m;
import '../../services/errors.dart';
import '../../services/staff_admin_service.dart';
import '../../theme/app_theme.dart';
import '../data/proto_store.dart';
import '../widgets/proto_ui.dart';

const _svc = StaffAdminService.instance;

String _genPassword() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
  final r = Random.secure();
  return List.generate(12, (_) => chars[r.nextInt(chars.length)]).join();
}

String _msg(Object e) => e is Exception && e.toString().startsWith('Exception: ')
    ? e.toString().substring(11)
    : friendlyError(e);

/// Personal del local: alta de cuentas (correo + contraseña), permisos,
/// eventos asignados, activar/desactivar y reseteo de contraseña.
class StaffAccountsPage extends StatefulWidget {
  const StaffAccountsPage({super.key});
  @override
  State<StaffAccountsPage> createState() => _StaffAccountsPageState();
}

class _StaffAccountsPageState extends State<StaffAccountsPage> {
  List<StaffAccount> _list = [];
  List<m.EventItem> _events = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([_svc.list(), AdminRepository.instance.listEvents()]);
      if (!mounted) return;
      setState(() {
        _list = r[0] as List<StaffAccount>;
        _events = r[1] as List<m.EventItem>;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _msg(e);
      });
    }
  }

  Future<void> _run(Future<void> Function() action, String ok) async {
    try {
      await action();
      await _load();
      if (mounted) toast(context, ok);
    } catch (e) {
      if (mounted) toast(context, _msg(e), error: true);
    }
  }

  Future<void> _create() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateStaffDialog(existing: _list, events: _events),
    );
    if (ok == true) {
      await _load();
      if (mounted) toast(context, 'Cuenta de staff creada');
    }
  }

  Future<void> _editPerms(StaffAccount a) async {
    final res = await showDialog<Set<StaffPermission>>(
      context: context,
      builder: (_) => _PermsDialog(title: 'Permisos de ${a.name}', initial: a.permissions),
    );
    if (res != null) await _run(() => _svc.updatePermissions(a, res), 'Permisos actualizados');
  }

  Future<void> _editEvents(StaffAccount a) async {
    final res = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _EventsDialog(title: 'Eventos de ${a.name}', events: _events, initial: a.eventIds),
    );
    if (res != null) await _run(() => _svc.setEvents(a, res), 'Eventos actualizados');
  }

  Future<void> _reset(StaffAccount a) async {
    final pass = await showDialog<String>(context: context, builder: (_) => _ResetDialog(name: a.name));
    if (pass == null) return;
    try {
      await _svc.resetPassword(a, pass);
      if (mounted) toast(context, 'Contraseña actualizada');
    } catch (e) {
      if (mounted) toast(context, _msg(e), error: true);
    }
  }

  Future<void> _delete(StaffAccount a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: Text('Eliminar a ${a.name}'),
        content: const Text('La cuenta se elimina de forma definitiva. Si ya tiene historial en eventos, desactívala en su lugar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (ok == true) await _run(() => _svc.delete(a), 'Cuenta eliminada');
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBody(
      maxWidth: 900,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H('Personal del local', sub: 'Crea el acceso de tu staff con correo y contraseña, y define qué puede hacer cada persona.'),
        PButton('Crear cuenta de staff', icon: Icons.person_add_alt_1, onPressed: _loading ? null : _create),
        const SizedBox(height: 16),
        if (_loading)
          const StateView(ViewState.loading)
        else if (_error != null)
          StateView(ViewState.error, message: _error, onRetry: () {
            setState(() => _loading = true);
            _load();
          })
        else if (_list.isEmpty)
          const StateView(ViewState.empty, message: 'Aún no creaste cuentas de staff.')
        else
          for (final a in _list)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    CircleAvatar(backgroundColor: AppColors.bgBorder, child: Text(a.name.isEmpty ? '?' : a.name[0].toUpperCase())),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(a.name, style: ts(AppTextSize.bodyLg, w: FontWeight.w600)),
                        Text(a.email, style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
                        if (a.job.isNotEmpty) Text(a.job, style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
                      ]),
                    ),
                    Chip2(a.active ? 'Activa' : 'Desactivada', a.active ? AppColors.success : AppColors.textSecondary),
                  ]),
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    if (a.permissions.isEmpty) Text('Sin permisos', style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
                    for (final p in a.permissions) Chip2(p.label, AppColors.accentPrimary),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    a.eventIds.isEmpty ? 'Sin eventos asignados' : '${a.eventIds.length} evento(s) asignado(s)',
                    style: ts(AppTextSize.caption, c: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    SizedBox(width: 150, child: PButton('Permisos', kind: BtnKind.secondary, icon: Icons.tune, onPressed: () => _editPerms(a))),
                    SizedBox(width: 150, child: PButton('Eventos', kind: BtnKind.secondary, icon: Icons.event_outlined, onPressed: () => _editEvents(a))),
                    SizedBox(width: 150, child: PButton('Contraseña', kind: BtnKind.secondary, icon: Icons.key, onPressed: () => _reset(a))),
                    SizedBox(
                      width: 150,
                      child: PButton(a.active ? 'Desactivar' : 'Reactivar', kind: BtnKind.secondary,
                          onPressed: () => _run(() => _svc.setActive(a, !a.active), a.active ? 'Cuenta desactivada' : 'Cuenta reactivada')),
                    ),
                    SizedBox(width: 150, child: PButton('Eliminar', kind: BtnKind.danger, onPressed: () => _delete(a))),
                  ]),
                ]),
              ),
            ),
      ]),
    );
  }
}

class _PermChecks extends StatelessWidget {
  const _PermChecks({required this.selected, required this.onChanged});
  final Set<StaffPermission> selected;
  final void Function(StaffPermission, bool) onChanged;
  @override
  Widget build(BuildContext context) => Column(children: [
        for (final p in StaffPermission.values)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: selected.contains(p),
            onChanged: (v) => onChanged(p, v ?? false),
            title: Text(p.label, style: ts(AppTextSize.body, w: FontWeight.w600)),
            subtitle: Text(p.description, style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
          ),
      ]);
}

class _EventChecks extends StatelessWidget {
  const _EventChecks({required this.events, required this.selected, required this.onChanged});
  final List<m.EventItem> events;
  final Set<String> selected;
  final void Function(String, bool) onChanged;
  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return Text('Aún no hay eventos.', style: ts(AppTextSize.caption, c: AppColors.textSecondary));
    return Column(children: [
      for (final e in events)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: selected.contains(e.id),
          onChanged: (v) => onChanged(e.id, v ?? false),
          title: Text(e.name, style: ts(AppTextSize.body, w: FontWeight.w600)),
          subtitle: Text('${e.date} · ${e.time}', style: ts(AppTextSize.caption, c: AppColors.textSecondary)),
        ),
    ]);
  }
}

class _PermsDialog extends StatefulWidget {
  const _PermsDialog({required this.title, required this.initial});
  final String title;
  final Set<StaffPermission> initial;
  @override
  State<_PermsDialog> createState() => _PermsDialogState();
}

class _PermsDialogState extends State<_PermsDialog> {
  late final Set<StaffPermission> _sel = {...widget.initial};
  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: Text(widget.title),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: _PermChecks(selected: _sel, onChanged: (p, v) => setState(() => v ? _sel.add(p) : _sel.remove(p))),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, _sel), child: const Text('Guardar')),
        ],
      );
}

class _EventsDialog extends StatefulWidget {
  const _EventsDialog({required this.title, required this.events, required this.initial});
  final String title;
  final List<m.EventItem> events;
  final Set<String> initial;
  @override
  State<_EventsDialog> createState() => _EventsDialogState();
}

class _EventsDialogState extends State<_EventsDialog> {
  late final Set<String> _sel = {...widget.initial};
  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: Text(widget.title),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: _EventChecks(events: widget.events, selected: _sel, onChanged: (id, v) => setState(() => v ? _sel.add(id) : _sel.remove(id))),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, _sel), child: const Text('Guardar')),
        ],
      );
}

class _ResetDialog extends StatefulWidget {
  const _ResetDialog({required this.name});
  final String name;
  @override
  State<_ResetDialog> createState() => _ResetDialogState();
}

class _ResetDialogState extends State<_ResetDialog> {
  final _pass = TextEditingController(text: _genPassword());
  bool _show = false;
  @override
  void dispose() {
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: Text('Nueva contraseña para ${widget.name}'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: _pass,
            obscureText: !_show,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Contraseña (8 a 72 caracteres)',
              suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(tooltip: 'Mostrar', icon: Icon(_show ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _show = !_show)),
                IconButton(tooltip: 'Generar', icon: const Icon(Icons.autorenew), onPressed: () => setState(() => _pass.text = _genPassword())),
                IconButton(tooltip: 'Copiar', icon: const Icon(Icons.copy), onPressed: () => Clipboard.setData(ClipboardData(text: _pass.text))),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: _pass.text.length >= 8 && _pass.text.length <= 72 ? () => Navigator.pop(context, _pass.text) : null,
            child: const Text('Cambiar'),
          ),
        ],
      );
}

class _CreateStaffDialog extends StatefulWidget {
  const _CreateStaffDialog({required this.existing, required this.events});
  final List<StaffAccount> existing;
  final List<m.EventItem> events;
  @override
  State<_CreateStaffDialog> createState() => _CreateStaffDialogState();
}

class _CreateStaffDialogState extends State<_CreateStaffDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _job = TextEditingController();
  final _pass = TextEditingController();
  final Set<StaffPermission> _sel = {StaffPermission.scanQr};
  final Set<String> _evSel = {};
  bool _show = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pass.text = _genPassword();
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _job, _pass]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validate() {
    if (_name.text.trim().length < 2) return 'Escribe el nombre completo.';
    final mail = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(mail)) return 'Correo no válido.';
    if (_svc.emailTaken(widget.existing, mail)) return 'Ya existe una cuenta con ese correo.';
    if (_pass.text.length < 8 || _pass.text.length > 72) return 'La contraseña debe tener entre 8 y 72 caracteres.';
    if (_sel.isEmpty) return 'Asigna al menos un permiso.';
    return null;
  }

  Future<void> _submit() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _svc.create(
        name: _name.text.trim(),
        email: _email.text.trim(),
        job: _job.text.trim(),
        password: _pass.text,
        permissions: _sel,
        eventIds: _evSel,
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
        title: const Text('Nueva cuenta de staff'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre completo')),
              const SizedBox(height: 10),
              TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Correo')),
              const SizedBox(height: 10),
              TextField(controller: _job, decoration: const InputDecoration(labelText: 'Cargo (opcional)')),
              const SizedBox(height: 10),
              TextField(
                controller: _pass,
                obscureText: !_show,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(tooltip: 'Mostrar', icon: Icon(_show ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _show = !_show)),
                    IconButton(tooltip: 'Generar', icon: const Icon(Icons.autorenew), onPressed: () => setState(() => _pass.text = _genPassword())),
                    IconButton(tooltip: 'Copiar', icon: const Icon(Icons.copy), onPressed: () => Clipboard.setData(ClipboardData(text: _pass.text))),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              Text('Permisos', style: ts(AppTextSize.body, w: FontWeight.w700)),
              _PermChecks(selected: _sel, onChanged: (p, v) => setState(() => v ? _sel.add(p) : _sel.remove(p))),
              const SizedBox(height: 10),
              Text('Eventos asignados', style: ts(AppTextSize.body, w: FontWeight.w700)),
              _EventChecks(events: widget.events, selected: _evSel, onChanged: (id, v) => setState(() => v ? _evSel.add(id) : _evSel.remove(id))),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: ts(AppTextSize.caption, c: AppColors.error))),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Creando…' : 'Crear cuenta')),
        ],
      );
}
