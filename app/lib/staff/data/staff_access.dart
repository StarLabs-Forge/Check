import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/demo_mode.dart';
import '../../proto/data/proto_store.dart';
import '../../services/app_session.dart';

/// Permisos y estado de la cuenta del staff autenticado.
///
/// La base ya los impone (RLS + `can_operate_door` / `can_verify_payments`);
/// esto solo decide qué muestra la interfaz.
class StaffAccess {
  const StaffAccess({required this.permissions, required this.active});

  /// Cuentas sin fila en `staff_accounts` (acceso por código de invitación):
  /// pueden ver sus eventos y escanear, como antes.
  static const legacy = StaffAccess(permissions: {StaffPermission.scanQr, StaffPermission.viewEvents}, active: true);

  final Set<StaffPermission> permissions;
  final bool active;

  bool can(StaffPermission p) => active && permissions.contains(p);

  /// Lee `staff_accounts` del usuario (modo real) o la cuenta demo equivalente.
  static Future<StaffAccess> load() async {
    if (kDemo) return _demo();
    final db = Supabase.instance.client;
    final uid = db.auth.currentUser?.id;
    if (uid == null) return const StaffAccess(permissions: {}, active: false);
    final row = await db.from('staff_accounts').select('permissions, active').eq('staff_id', uid).maybeSingle();
    if (row == null) return legacy;
    return StaffAccess(
      permissions: {
        for (final p in (row['permissions'] as List? ?? const []))
          ...StaffPermission.values.where((v) => v.name == p),
      },
      active: row['active'] as bool? ?? true,
    );
  }

  static StaffAccess _demo() {
    final email = AppSession.demoEmail?.toLowerCase();
    for (final a in ProtoStore.instance.staffAccounts) {
      if (a.email == email) return StaffAccess(permissions: {...a.permissions}, active: a.active);
    }
    return const StaffAccess(permissions: {...StaffPermission.values}, active: true);
  }
}
