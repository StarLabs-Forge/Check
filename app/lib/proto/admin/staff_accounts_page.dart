import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/demo_mode.dart';
import '../../theme/app_theme.dart';
import '../data/proto_store.dart';
import '../widgets/proto_ui.dart';

final _store = ProtoStore.instance;

/// Crea la cuenta en Supabase Auth mediante la Edge Function `create-staff`
/// (requiere la service role, que nunca viaja en la app). En modo demo solo
/// se guarda en memoria.
Future<void> _createRemote({
  required String name,
  required String email,
  required String password,
  required Set<StaffPermission> permissions,
}) async {
  if (kDemo) return;
  final res = await Supabase.instance.client.functions.invoke('create-staff', body: {
    'full_name': name,
    'email': email,
    'password': password,
    'permissions': [for (final p in permissions) p.name],
  });
  final data = res.data;
  if (res.status >= 400 || (data is Map && data['error'] != null)) {
    throw Exception(data is Map ? data['error'] : 'No se pudo crear la cuenta');
  }
}

String _genPassword() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
  final r = Random.secure();
  return List.generate(12, (_) => chars[r.nextInt(chars.length)]).join();
}

/// Personal del local: alta de cuentas (correo + contraseña) y permisos.
class StaffAccountsPage extends StatelessWidget {
  const StaffAccountsPage({super.key});

  Future<void> _create(BuildContext context) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const _CreateStaffDialog());
    if (ok == true && context.mounted) toast(context, 'Cuenta de staff creada');
  }

  Future<void> _editPerms(BuildContext context, StaffAccount a) async {
    final res = await showDialog<Set<StaffPermission>>(
      context: context,
      builder: (_) => _PermsDialog(title: 'Permisos de ${a.name}', initial: a.permissions),
    );
    if (res != null) {
      _store.updateStaffPermissions(a.id, res);
      if (context.mounted) toast(context, 'Permisos actualizados');
    }
  }

  Future<void> _delete(BuildContext context, StaffAccount a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: Text('Eliminar a ${a.name}'),
        content: const Text('La cuenta dejará de existir en el panel. Para bloquear el acceso temporalmente usa «Desactivar».'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (ok == true) _store.deleteStaffAccount(a.id);
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBody(
      maxWidth: 900,
      child: ListenableBuilder(
        listenable: _store,
        builder: (context, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H('Personal del local', sub: 'Crea el acceso de tu staff con correo y contraseña, y define qué puede hacer cada persona.'),
          PButton('Crear cuenta de staff', icon: Icons.person_add_alt_1, onPressed: () => _create(context)),
          const SizedBox(height: 16),
          if (_store.staffAccounts.isEmpty)
            const StateView(ViewState.empty, message: 'Aún no creaste cuentas de staff.')
          else
            for (final a in _store.staffAccounts)
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
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      SizedBox(width: 160, child: PButton('Permisos', kind: BtnKind.secondary, icon: Icons.tune, onPressed: () => _editPerms(context, a))),
                      SizedBox(
                        width: 160,
                        child: PButton(a.active ? 'Desactivar' : 'Reactivar', kind: BtnKind.secondary, onPressed: () => _store.setStaffActive(a.id, !a.active)),
                      ),
                      SizedBox(width: 160, child: PButton('Eliminar', kind: BtnKind.danger, onPressed: () => _delete(context, a))),
                    ]),
                  ]),
                ),
              ),
        ]),
      ),
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

class _CreateStaffDialog extends StatefulWidget {
  const _CreateStaffDialog();
  @override
  State<_CreateStaffDialog> createState() => _CreateStaffDialogState();
}

class _CreateStaffDialogState extends State<_CreateStaffDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _job = TextEditingController();
  final _pass = TextEditingController();
  final Set<StaffPermission> _sel = {StaffPermission.scanQr};
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
    if (_store.staffEmailTaken(mail)) return 'Ya existe una cuenta con ese correo.';
    if (_pass.text.length < 8) return 'La contraseña debe tener al menos 8 caracteres.';
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
      await _createRemote(name: _name.text.trim(), email: _email.text.trim(), password: _pass.text, permissions: _sel);
      _store.createStaffAccount(name: _name.text, email: _email.text, job: _job.text, permissions: _sel);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString().replaceFirst('Exception: ', '');
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
