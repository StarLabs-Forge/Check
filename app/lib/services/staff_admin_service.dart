import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/demo_mode.dart';
import '../proto/data/proto_store.dart';

/// Gestión de cuentas de staff por el administrador.
///
/// Modo real: lee `staff_accounts` (RLS: solo las del dueño), usa las RPC
/// `staff_update` / `staff_set_events` y la Edge Function `create-staff`
/// (única que toca Auth con la service role). Modo demo: [ProtoStore].
class StaffAdminService {
  const StaffAdminService._();
  static const instance = StaffAdminService._();

  SupabaseClient get _db => Supabase.instance.client;
  ProtoStore get _demo => ProtoStore.instance;

  Future<List<StaffAccount>> list() async {
    if (kDemo) return List.of(_demo.staffAccounts);
    final rows = await _db.from('staff_accounts').select().order('created_at', ascending: false);
    final out = <StaffAccount>[];
    for (final r in rows) {
      final id = r['staff_id'] as String;
      final ev = await _db.rpc('staff_event_ids', params: {'p_staff_id': id});
      out.add(StaffAccount(
        id: id,
        name: (r['full_name'] as String?) ?? '',
        email: (r['email'] as String?) ?? '',
        job: (r['job'] as String?) ?? '',
        permissions: {
          for (final p in (r['permissions'] as List? ?? const []))
            ...StaffPermission.values.where((v) => v.name == p),
        },
        active: r['active'] as bool? ?? true,
        eventIds: {for (final e in (ev as List? ?? const [])) '$e'},
        createdAt: DateTime.tryParse('${r['created_at']}'),
      ));
    }
    return out;
  }

  Future<Map<String, dynamic>> _fn(Map<String, dynamic> body) async {
    final res = await _db.functions.invoke('create-staff', body: body);
    final data = res.data;
    if (res.status >= 400 || (data is Map && data['error'] != null)) {
      throw Exception(data is Map ? '${data['error']}' : 'No se pudo completar la acción');
    }
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  Future<void> create({
    required String name,
    required String email,
    required String job,
    required String password,
    required Set<StaffPermission> permissions,
    required Set<String> eventIds,
  }) async {
    if (kDemo) {
      _demo.createStaffAccount(name: name, email: email, job: job, permissions: permissions, eventIds: eventIds);
      return;
    }
    final res = await _fn({
      'action': 'create',
      'full_name': name,
      'email': email,
      'job': job,
      'password': password,
      'permissions': [for (final p in permissions) p.name],
    });
    if (eventIds.isNotEmpty) {
      await _db.rpc('staff_set_events', params: {'p_staff_id': res['id'], 'p_event_ids': eventIds.toList()});
    }
  }

  Future<void> updatePermissions(StaffAccount a, Set<StaffPermission> perms) async {
    if (kDemo) return _demo.updateStaffPermissions(a.id, perms);
    await _db.rpc('staff_update', params: {
      'p_staff_id': a.id,
      'p_job': null,
      'p_permissions': [for (final p in perms) p.name],
      'p_active': null,
    });
  }

  Future<void> setEvents(StaffAccount a, Set<String> ids) async {
    if (kDemo) return _demo.setStaffEvents(a.id, ids);
    await _db.rpc('staff_set_events', params: {'p_staff_id': a.id, 'p_event_ids': ids.toList()});
  }

  Future<void> setActive(StaffAccount a, bool active) async {
    if (kDemo) return _demo.setStaffActive(a.id, active);
    await _fn({'action': 'set_active', 'staff_id': a.id, 'active': active});
  }

  Future<void> resetPassword(StaffAccount a, String password) async {
    if (kDemo) return;
    await _fn({'action': 'reset_password', 'staff_id': a.id, 'password': password});
  }

  Future<void> delete(StaffAccount a) async {
    if (kDemo) return _demo.deleteStaffAccount(a.id);
    await _fn({'action': 'delete', 'staff_id': a.id});
  }

  /// `true` si el correo ya figura en las cuentas cargadas (la base también lo rechaza).
  bool emailTaken(List<StaffAccount> list, String email) =>
      list.any((a) => a.email.toLowerCase() == email.trim().toLowerCase());
}
