import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/demo_mode.dart';
import '../proto/data/proto_store.dart';

DateTime? _dt(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();
int _int(Object? v) => (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;

class SaVenue {
  SaVenue({
    required this.ownerId,
    required this.name,
    required this.zone,
    required this.plan,
    required this.active,
    this.createdAt,
    this.events = 0,
    this.eventsActive = 0,
    this.tickets = 0,
    this.orders = const {},
    this.verifiers = 0,
    this.lastActivity,
  });
  final String ownerId;
  final String name;
  final String zone;
  String plan;
  bool active;
  final DateTime? createdAt;
  final int events;
  final int eventsActive;
  final int tickets;
  final Map<String, int> orders;
  final int verifiers;
  final DateTime? lastActivity;

  int order(String status) => orders[status] ?? 0;
}

class SaEvent {
  const SaEvent({required this.id, required this.name, required this.ownerId, required this.venueName, required this.startsAt, required this.status, required this.capacity});
  final String id;
  final String name;
  final String ownerId;
  final String venueName;
  final DateTime startsAt;
  final String status;
  final int capacity;
}

class SaAudit {
  const SaAudit({required this.ownerId, required this.venueName, this.approved = 0, this.rejected = 0, this.conflicts = 0, this.byVerifiers = 0, this.permissionChanges = 0, this.lastActivity});
  final String ownerId;
  final String venueName;
  final int approved;
  final int rejected;
  final int conflicts;
  final int byVerifiers;
  final int permissionChanges;
  final DateTime? lastActivity;
}

class SaLog {
  const SaLog({required this.at, required this.action, this.detail, this.venueName});
  final DateTime at;
  final String action;
  final String? detail;
  final String? venueName;

  String get label => switch (action) {
        'venue_suspended' => 'Local suspendido',
        'venue_activated' => 'Local reactivado',
        'plan_changed' => 'Plan cambiado',
        'venue_created' => 'Local creado',
        'plan_limits_changed' => 'Límites de plan editados',
        'settings_changed' => 'Ajustes de plataforma',
        _ => action,
      };
}

class SaUser {
  const SaUser({required this.ownerId, required this.fullName, required this.email, required this.venueName, required this.plan, required this.active, this.createdAt, this.lastSignIn});
  final String ownerId;
  final String fullName;
  final String email;
  final String venueName;
  final String plan;
  final bool active;
  final DateTime? createdAt;
  final DateTime? lastSignIn;
}

class SaPlan {
  SaPlan({required this.plan, this.maxEvents, this.maxStaff, this.maxTickets, this.priceBs = 0});
  final String plan;
  int? maxEvents;
  int? maxStaff;
  int? maxTickets;
  double priceBs;
}

class SaSettings {
  SaSettings({this.registrationOpen = true, this.maintenance = false, this.message = '', this.defaultPlan = 'starter'});
  bool registrationOpen;
  bool maintenance;
  String message;
  String defaultPlan;
}

/// Datos y acciones del panel Super Admin.
///
/// Modo real: solo RPC `superadmin_*` y la Edge Function `create-venue`
/// (todas exigen rol super_admin en la base; no se lee ningún dato de
/// empleados ni compradores). Modo demo: se arma desde [ProtoStore] y se
/// mantiene en memoria.
class SuperadminService extends ChangeNotifier {
  SuperadminService._();
  static final SuperadminService instance = SuperadminService._();

  SupabaseClient get _db => Supabase.instance.client;

  bool loading = false;
  String? error;
  List<SaVenue> venues = [];
  List<SaEvent> events = [];
  List<SaAudit> audit = [];
  List<SaLog> log = [];
  List<SaUser> users = [];
  List<SaPlan> plans = [];
  SaSettings settings = SaSettings();

  static const planNames = {'starter': 'Starter', 'pro': 'Pro', 'premium': 'Premium'};
  static String planLabel(String p) => planNames[p] ?? p;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      if (kDemo) {
        _loadDemo();
      } else {
        await _loadReal();
      }
    } catch (e) {
      error = '$e';
    }
    loading = false;
    notifyListeners();
  }

  // ───────────────────────── real ─────────────────────────
  Future<void> _loadReal() async {
    final r = await Future.wait<dynamic>([
      _db.rpc('superadmin_venues_overview'),
      _db.rpc('superadmin_audit_summary'),
      _db.rpc('superadmin_users'),
      _db.from('plan_limits').select().order('plan'),
      _db.from('platform_settings').select().maybeSingle(),
      _db.from('platform_log').select().order('created_at', ascending: false).limit(200),
      _db.from('events').select('id, owner_id, name, starts_at, status, capacity').order('starts_at', ascending: false).limit(300),
    ]);

    venues = [
      for (final m in (r[0] as List).cast<Map>())
        SaVenue(
          ownerId: m['owner_id'] as String,
          name: (m['venue_name'] as String?) ?? 'Sin nombre',
          zone: (m['zone'] as String?) ?? '',
          plan: m['plan'] as String,
          active: m['status'] == 'active',
          createdAt: _dt(m['created_at']),
          events: _int(m['events']),
          eventsActive: _int(m['events_active']),
          tickets: _int(m['tickets_issued']),
          orders: {for (final e in ((m['orders'] as Map?) ?? const {}).entries) '${e.key}': _int(e.value)},
          verifiers: _int(m['verifiers']),
          lastActivity: _dt(m['last_activity']),
        ),
    ];
    final names = {for (final v in venues) v.ownerId: v.name};

    audit = [
      for (final m in (r[1] as List).cast<Map>())
        SaAudit(
          ownerId: m['owner_id'] as String,
          venueName: (m['venue_name'] as String?) ?? 'Sin nombre',
          approved: _int(m['approved']),
          rejected: _int(m['rejected']),
          conflicts: _int(m['conflicts']),
          byVerifiers: _int(m['by_verifiers']),
          permissionChanges: _int(m['permission_changes']),
          lastActivity: _dt(m['last_activity']),
        ),
    ];

    users = [
      for (final m in (r[2] as List).cast<Map>())
        SaUser(
          ownerId: m['owner_id'] as String,
          fullName: (m['full_name'] as String?) ?? '',
          email: (m['email'] as String?) ?? '',
          venueName: (m['venue_name'] as String?) ?? 'Sin nombre',
          plan: m['plan'] as String,
          active: m['status'] == 'active',
          createdAt: _dt(m['created_at']),
          lastSignIn: _dt(m['last_sign_in_at']),
        ),
    ];

    plans = [
      for (final m in (r[3] as List).cast<Map>())
        SaPlan(
          plan: m['plan'] as String,
          maxEvents: m['max_events_month'] as int?,
          maxStaff: m['max_staff_per_event'] as int?,
          maxTickets: m['max_tickets_month'] as int?,
          priceBs: double.tryParse('${m['price_bs']}') ?? 0,
        ),
    ];

    final s = r[4] as Map?;
    if (s != null) {
      settings = SaSettings(
        registrationOpen: s['registration_open'] as bool? ?? true,
        maintenance: s['maintenance'] as bool? ?? false,
        message: (s['maintenance_message'] as String?) ?? '',
        defaultPlan: s['default_plan'] as String? ?? 'starter',
      );
    }

    log = [
      for (final m in (r[5] as List).cast<Map>())
        SaLog(at: _dt(m['created_at'])!, action: m['action'] as String, detail: m['detail'] as String?, venueName: names[m['target_owner_id']]),
    ];

    events = [
      for (final m in (r[6] as List).cast<Map>())
        SaEvent(
          id: m['id'] as String,
          name: m['name'] as String,
          ownerId: m['owner_id'] as String,
          venueName: names[m['owner_id']] ?? 'Sin nombre',
          startsAt: _dt(m['starts_at'])!,
          status: '${m['status']}',
          capacity: _int(m['capacity']),
        ),
    ];
  }

  // ───────────────────────── demo ─────────────────────────
  void _loadDemo() {
    final st = ProtoStore.instance;
    if (venues.isEmpty) {
      venues = [
        for (final v in st.venues)
          SaVenue(
            ownerId: v.id,
            name: v.name,
            zone: v.zone,
            plan: switch (v.plan) { 'Pro' => 'pro', 'Local Premium' => 'premium', _ => 'starter' },
            active: v.active,
            createdAt: DateTime.now().subtract(const Duration(days: 30)),
          ),
      ];
      plans = [
        SaPlan(plan: 'starter', maxEvents: 4, maxStaff: 2, maxTickets: 200, priceBs: 0),
        SaPlan(plan: 'pro', priceBs: 199),
        SaPlan(plan: 'premium', priceBs: 399),
      ];
      log = [for (final a in st.platformLog) SaLog(at: a.at, action: 'venue_created', detail: a.result, venueName: a.venue)];
    }
    events = [
      for (final e in st.events)
        SaEvent(
          id: e.id,
          name: e.name,
          ownerId: e.venueId,
          venueName: st.venueById(e.venueId).name,
          startsAt: e.date,
          status: switch (e.state) { EventState.active => 'live', EventState.upcoming => 'active', EventState.finished => 'finished' },
          capacity: e.totalCapacity,
        ),
    ];
    venues = [
      for (final v in venues)
        SaVenue(
          ownerId: v.ownerId,
          name: v.name,
          zone: v.zone,
          plan: v.plan,
          active: v.active,
          createdAt: v.createdAt,
          events: events.where((e) => e.ownerId == v.ownerId).length,
          eventsActive: events.where((e) => e.ownerId == v.ownerId && (e.status == 'live' || e.status == 'active')).length,
          tickets: events.where((e) => e.ownerId == v.ownerId).fold(0, (s, e) => s + st.ticketsSold(e.id)),
          orders: {
            for (final o in st.orders.where((o) => st.eventById(o.eventId).venueId == v.ownerId)) o.status.name: 0,
          }..updateAll((k, _) => st.orders.where((o) => st.eventById(o.eventId).venueId == v.ownerId && o.status.name == k).length),
        )
          ..plan = v.plan,
    ];
    audit = [
      for (final v in venues)
        SaAudit(
          ownerId: v.ownerId,
          venueName: v.name,
          approved: st.audit.where((a) => a.action.contains('Aprobó')).length,
          rejected: st.audit.where((a) => a.action.contains('Rechazó')).length,
        ),
    ];
    users = [
      for (final v in venues)
        SaUser(ownerId: v.ownerId, fullName: 'Administrador de ${v.name}', email: 'admin@${v.name.toLowerCase().replaceAll(' ', '')}.demo', venueName: v.name, plan: v.plan, active: v.active, createdAt: v.createdAt),
    ];
  }

  void _logDemo(String action, {String? detail, String? venueName}) {
    log.insert(0, SaLog(at: DateTime.now(), action: action, detail: detail, venueName: venueName));
  }

  // ───────────────────────── acciones ─────────────────────────
  Future<void> setVenueActive(SaVenue v, bool active) async {
    if (kDemo) {
      v.active = active;
      _logDemo(active ? 'venue_activated' : 'venue_suspended', venueName: v.name);
      notifyListeners();
      return;
    }
    await _db.rpc('superadmin_set_venue_status', params: {'p_owner_id': v.ownerId, 'p_status': active ? 'active' : 'suspended'});
    await load();
  }

  Future<void> setVenuePlan(SaVenue v, String plan) async {
    if (kDemo) {
      _logDemo('plan_changed', detail: '${v.plan} -> $plan', venueName: v.name);
      v.plan = plan;
      notifyListeners();
      return;
    }
    await _db.rpc('superadmin_set_plan', params: {'p_owner_id': v.ownerId, 'p_plan': plan});
    await load();
  }

  Future<void> createVenue({
    required String venueName,
    required String zone,
    required String fullName,
    required String email,
    required String password,
    required String plan,
  }) async {
    if (kDemo) {
      venues.add(SaVenue(ownerId: 'demo-${venues.length + 1}', name: venueName, zone: zone, plan: plan, active: true, createdAt: DateTime.now()));
      users.insert(0, SaUser(ownerId: 'demo-${venues.length}', fullName: fullName, email: email, venueName: venueName, plan: plan, active: true, createdAt: DateTime.now()));
      _logDemo('venue_created', detail: venueName, venueName: venueName);
      notifyListeners();
      return;
    }
    final res = await _db.functions.invoke('create-venue', body: {
      'venue_name': venueName,
      'zone': zone,
      'full_name': fullName,
      'email': email,
      'password': password,
      'plan': plan,
    });
    final data = res.data;
    if (res.status >= 400 || (data is Map && data['error'] != null)) {
      throw Exception(data is Map ? '${data['error']}' : 'No se pudo crear el local');
    }
    await load();
  }

  Future<void> savePlan(SaPlan p) async {
    if (kDemo) {
      _logDemo('plan_limits_changed', detail: p.plan);
      notifyListeners();
      return;
    }
    await _db.rpc('superadmin_update_plan', params: {
      'p_plan': p.plan,
      'p_max_events': p.maxEvents,
      'p_max_staff': p.maxStaff,
      'p_max_tickets': p.maxTickets,
      'p_price': p.priceBs,
    });
    await load();
  }

  Future<void> saveSettings(SaSettings s) async {
    if (kDemo) {
      settings = s;
      _logDemo('settings_changed');
      PlatformStatus.instance.apply(registrationOpen: s.registrationOpen, maintenance: s.maintenance, message: s.message);
      notifyListeners();
      return;
    }
    await _db.rpc('superadmin_update_settings', params: {
      'p_registration_open': s.registrationOpen,
      'p_maintenance': s.maintenance,
      'p_message': s.message,
      'p_default_plan': s.defaultPlan,
    });
    await load();
    await PlatformStatus.instance.refresh();
  }
}

/// Estado público de la plataforma (registro abierto / mantenimiento).
/// Se consulta antes de iniciar sesión mediante la RPC `platform_status`.
class PlatformStatus extends ChangeNotifier {
  PlatformStatus._();
  static final PlatformStatus instance = PlatformStatus._();

  bool registrationOpen = true;
  bool maintenance = false;
  String message = '';

  void apply({required bool registrationOpen, required bool maintenance, required String message}) {
    this.registrationOpen = registrationOpen;
    this.maintenance = maintenance;
    this.message = message;
    notifyListeners();
  }

  /// Si la consulta falla se conserva el último estado (no se bloquea la app por un error de red).
  Future<void> refresh() async {
    if (kDemo) return;
    try {
      final r = await Supabase.instance.client.rpc('platform_status');
      if (r is Map) {
        apply(
          registrationOpen: r['registration_open'] as bool? ?? true,
          maintenance: r['maintenance'] as bool? ?? false,
          message: (r['message'] as String?) ?? '',
        );
      }
    } catch (_) {}
  }
}
