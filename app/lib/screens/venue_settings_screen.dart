import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/demo_mode.dart';
import '../proto/data/proto_store.dart';
import '../services/app_session.dart';
import '../services/errors.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_scaffold.dart';

/// Configuración del local: datos bancarios que ve el comprador al pagar.
///
/// Sin beneficiario, banco y cuenta el local no puede vender entradas por la
/// web pública (`create_order` responde `venue_payment_not_configured`).
class VenueSettingsScreen extends StatefulWidget {
  const VenueSettingsScreen({super.key});

  @override
  State<VenueSettingsScreen> createState() => _VenueSettingsScreenState();
}

class _VenueSettingsScreenState extends State<VenueSettingsScreen> {
  final _name = TextEditingController();
  final _zone = TextEditingController();
  final _beneficiary = TextEditingController();
  final _bank = TextEditingController();
  final _account = TextEditingController();

  bool _notifyPayment = true;
  bool _notifyCapacity = true;
  bool _notifySummary = false;

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _ok;

  SupabaseClient get _db => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _zone, _beneficiary, _bank, _account]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (kDemo) {
      _name.text = AppSession.profile.value?.venueName ?? 'Dharma Club';
      _zone.text = 'Zona Sur';
      _beneficiary.text = ProtoStore.bankBeneficiary;
      _bank.text = 'Banco Unión';
      _account.text = '1000012345678';
      setState(() => _loading = false);
      return;
    }
    try {
      final uid = _db.auth.currentUser!.id;
      final row = await _db.from('venues').select().eq('owner_id', uid).maybeSingle();
      if (row != null) {
        _name.text = (row['name'] as String?) ?? '';
        _zone.text = (row['zone'] as String?) ?? '';
        _beneficiary.text = (row['bank_beneficiary'] as String?) ?? '';
        _bank.text = (row['bank_name'] as String?) ?? '';
        _account.text = (row['bank_account'] as String?) ?? '';
      } else {
        // Local nuevo: propone el nombre dado al registrarse.
        _name.text = AppSession.profile.value?.venueName ?? '';
      }
      final prefs = await _db.from('venue_settings').select().eq('owner_id', uid).maybeSingle();
      if (prefs != null) {
        _notifyPayment = prefs['notify_new_payment'] as bool? ?? true;
        _notifyCapacity = prefs['notify_low_capacity'] as bool? ?? true;
        _notifySummary = prefs['notify_daily_summary'] as bool? ?? false;
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyError(e);
      });
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() {
        _error = 'Escribe el nombre del local.';
        _ok = null;
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _ok = null;
    });
    String? nn(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    if (kDemo) {
      if (_beneficiary.text.trim().isNotEmpty) ProtoStore.bankBeneficiary = _beneficiary.text.trim();
      setState(() {
        _saving = false;
        _ok = 'Modo demo: los cambios no se guardan en la base.';
      });
      return;
    }
    try {
      final uid = _db.auth.currentUser!.id;
      final data = {
        'name': name,
        'zone': nn(_zone),
        'bank_beneficiary': nn(_beneficiary),
        'bank_name': nn(_bank),
        'bank_account': nn(_account),
      };
      final existing = await _db.from('venues').select('id').eq('owner_id', uid).maybeSingle();
      if (existing == null) {
        await _db.from('venues').insert({'owner_id': uid, ...data});
      } else {
        await _db.from('venues').update(data).eq('owner_id', uid);
      }
      await _db.from('venue_settings').upsert({
        'owner_id': uid,
        'notify_new_payment': _notifyPayment,
        'notify_low_capacity': _notifyCapacity,
        'notify_daily_summary': _notifySummary,
      });
      if (!mounted) return;
      setState(() {
        _saving = false;
        _ok = 'Guardado. Los compradores verán estos datos al pagar.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = friendlyError(e);
      });
    }
  }

  Widget _field(String label, TextEditingController c, {String? hint}) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.caption, fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.s2),
            TextField(controller: c, decoration: InputDecoration(hintText: hint)),
          ],
        ),
      );

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accentPrimary));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s6),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Configuración del local', style: TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.h2, fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.s2),
              const Text(
                'Estos datos los ve el comprador al pagar. CHECK no mueve dinero: el pago va directo a tu cuenta.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
              ),
              const SizedBox(height: AppSpacing.s5),
              _field('Nombre del local', _name),
              _field('Zona', _zone, hint: 'Ej: Sopocachi'),
              _field('Beneficiario de la cuenta', _beneficiary, hint: 'Nombre o razón social'),
              _field('Banco', _bank, hint: 'Ej: Banco Unión'),
              _field('Número de cuenta', _account),
              const SizedBox(height: AppSpacing.s3),
              const Text('Avisos', style: TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.bodyLg, fontWeight: FontWeight.w700)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Pago nuevo por verificar'),
                value: _notifyPayment,
                onChanged: (v) => setState(() => _notifyPayment = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Capacidad casi agotada'),
                value: _notifyCapacity,
                onChanged: (v) => setState(() => _notifyCapacity = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Resumen diario'),
                value: _notifySummary,
                onChanged: (v) => setState(() => _notifySummary = v),
              ),
              const SizedBox(height: AppSpacing.s3),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                  child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: AppTextSize.body)),
                ),
              if (_ok != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                  child: Text(_ok!, style: const TextStyle(color: AppColors.success, fontSize: AppTextSize.body)),
                ),
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Guardar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(current: AdminRoute.configuracion, body: _body());
  }
}
