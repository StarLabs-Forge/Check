import 'package:flutter/material.dart';

import '../data/admin_repository.dart';
import '../services/errors.dart';
import '../theme/app_theme.dart';

/// Estado de la prueba gratuita de 14 días y del plan en el panel del local.
/// Todo se calcula en el servidor (`trial_status`); acá solo se muestra. Si no
/// hay prueba ofrece activarla una única vez. En demo o sin migración no se
/// muestra. No se inventan precios: la contratación la verifica el equipo CHECK.
class TrialBanner extends StatefulWidget {
  const TrialBanner({super.key, this.loadStatus, this.startTrial});

  /// Inyectables para pruebas; por defecto usan [AdminRepository].
  final Future<TrialStatus?> Function()? loadStatus;
  final Future<TrialStatus?> Function()? startTrial;

  @override
  State<TrialBanner> createState() => _TrialBannerState();
}

class _TrialBannerState extends State<TrialBanner> {
  final _repo = AdminRepository.instance;
  TrialStatus? _trial;
  bool _available = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final t = await (widget.loadStatus ?? _repo.trialStatus)();
      if (mounted) setState(() { _trial = t; _available = true; });
    } catch (_) {
      if (mounted) setState(() => _available = false);
    }
  }

  Future<void> _start() async {
    setState(() { _busy = true; _error = null; });
    try {
      final t = await (widget.startTrial ?? _repo.startTrial)();
      if (mounted) setState(() => _trial = t);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  static const _contract =
      'Para contratar un plan (Starter, Pro o Premium) contacta al equipo de CHECK: '
      'el plan se activa cuando verifican tu pago.';

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (!_available) return const SizedBox.shrink();
    final t = _trial;
    final String text;
    var color = AppColors.textSecondary;
    Widget? action;
    String? detail;
    if (t == null) {
      text = 'Prueba gratuita de 14 días disponible. Se activa una sola vez. '
          'Hasta activarla (o contratar un plan) puedes preparar todo en borrador, pero no publicar ni vender.';
      action = TextButton(
        onPressed: _busy ? null : _start,
        child: Text(_busy ? 'Activando…' : 'Activar prueba'),
      );
    } else if (t.state == 'subscribed') {
      final plan = t.plan == null ? '' : ' ${t.plan![0].toUpperCase()}${t.plan!.substring(1)}';
      text = 'Plan$plan activo.';
    } else if (t.state == 'plan_ended') {
      text = 'Tu plan terminó. Tus datos se conservan y puedes resolver pagos pendientes y controlar accesos.';
      color = AppColors.error;
      detail = _contract;
    } else if (t.expired) {
      text = 'Tu prueba gratuita terminó. Tus datos se conservan y puedes resolver pagos pendientes y '
          'controlar accesos, pero no publicar ni vender.';
      color = AppColors.error;
      detail = _contract;
    } else if (t.state == 'expiring') {
      text = 'Tu prueba termina en ${t.daysLeft} día(s). Elige un plan para no perder continuidad.';
      color = AppColors.error;
      detail = _contract;
    } else {
      text = 'Prueba gratuita: ${t.daysLeft} día(s) restantes.';
      detail = _contract;
    }
    final endsAt = t?.endsAt;
    if (endsAt != null) detail = '${t!.expired ? 'Venció' : 'Vence'} el ${_date(endsAt)}. ${detail ?? ''}'.trim();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.s3,
        children: [
          Text(text, style: TextStyle(color: color, fontSize: AppTextSize.body)),
          ?action,
          if (detail != null) Text(detail, style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.caption)),
          if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.error)),
        ],
      ),
    );
  }
}
