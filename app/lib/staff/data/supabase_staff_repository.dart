import 'package:supabase_flutter/supabase_flutter.dart';

import 'staff_models.dart';
import 'staff_repository.dart';

/// La base rechazó la operación por permisos o cuenta desactivada (42501).
class StaffForbidden implements Exception {
  const StaffForbidden();
  @override
  String toString() => 'forbidden';
}

/// Repositorio real del staff: eventos asignados (RLS) y validación de QR con
/// la RPC `validate_qr`, que exige permiso `scanQr` y cuenta activa.
class SupabaseStaffRepository implements StaffRepository {
  SupabaseClient get _db => Supabase.instance.client;

  @override
  Future<void> signOut() => _db.auth.signOut();

  @override
  Future<bool> isOnline() async {
    try {
      await _db.from('profiles').select('id').limit(1);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<int> _checkins(String eventId) async {
    try {
      final r = await _db.from('event_stats').select('checked_in').eq('event_id', eventId).maybeSingle();
      return ((r?['checked_in']) as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<List<StaffEvent>> assignedEvents() async {
    final rows = await _db
        .from('events')
        .select('id, name, starts_at, capacity')
        .inFilter('status', ['active', 'live'])
        .order('starts_at');
    final out = <StaffEvent>[];
    for (final r in rows) {
      out.add(StaffEvent(
        id: r['id'] as String,
        name: r['name'] as String,
        startsAt: DateTime.parse(r['starts_at'] as String),
        capacity: (r['capacity'] as num).toInt(),
        checkins: await _checkins(r['id'] as String),
      ));
    }
    return out;
  }

  @override
  Future<ScanOutcome> scanQr({required String eventId, required String token}) async {
    final Map<String, dynamic> res;
    try {
      final raw = await _db.rpc('validate_qr', params: {'p_token': token.trim(), 'p_event_id': eventId});
      res = Map<String, dynamic>.from(raw as Map);
    } on PostgrestException catch (e) {
      if (e.code == '42501') throw const StaffForbidden();
      if (e.message.contains('commercial_inactive')) {
        return const ScanOutcome.denied(reason: 'El local no tiene activado el control de accesos.');
      }
      rethrow;
    }
    final name = (res['guest_name'] as String?) ?? '';
    final at = DateTime.tryParse('${res['checked_in_at']}')?.toLocal() ?? DateTime.now();
    switch (res['result']) {
      case 'valid':
        final ev = (await assignedEvents()).where((e) => e.id == eventId);
        return ScanOutcome.success(
          guestName: name,
          checkedInAt: at,
          checkins: ev.isEmpty ? 0 : ev.first.checkins,
          capacity: ev.isEmpty ? 0 : ev.first.capacity,
        );
      case 'already_used':
        return ScanOutcome.alreadyRegistered(guestName: name, checkedInAt: at);
      case 'event_inactive':
        return const ScanOutcome.denied(
            reason: 'El evento no está activo. La entrada no se marcó como usada: vuelve a intentarlo cuando se active.');
      default: // invalid, wrong_event, cancelled, pending_payment
        return const ScanOutcome.denied();
    }
  }
}
