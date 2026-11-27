import 'package:flutter/material.dart';

import '../data/admin_repository.dart';
import '../services/errors.dart';
import '../theme/app_theme.dart';

/// Estado de la prueba gratuita de 14 días en el panel del local. Todo se
/// calcula en el servidor (`trial_status`); acá solo se muestra. Si no hay
/// prueba ofrece activarla una única vez. En demo o sin migración no se muestra.
class TrialBanner extends StatefulWidget {
  const TrialBanner({super.key});

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
      final t = await _repo.trialStatus();
      if (mounted) setState(() { _trial = t; _available = true; });
    } catch (_) {
      if (mounted) setState(() => _available = false);
    }
  }

  Future<void> _start() async {
    setState(() { _busy = true; _error = null; });
    try {
      final t = await _repo.startTrial();
      if (mounted) setState(() => _trial = t);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) return const SizedBox.shrink();
    final t = _trial;
    final String text;
    var color = AppColors.textSecondary;
    Widget? action;
    if (t == null) {
      text = 'Prueba gratuita de 14 días disponible. Se activa una sola vez.';
      action = TextButton(
        onPressed: _busy ? null : _start,
        child: Text(_busy ? 'Activando…' : 'Activar prueba'),
      );
    } else if (t.expired) {
      text = 'Tu prueba gratuita terminó. Tus datos se conservan: elige un plan para continuar.';
      color = AppColors.error;
    } else if (t.state == 'expiring') {
      text = 'Tu prueba termina en ${t.daysLeft} día(s). Elige un plan para no perder continuidad.';
      color = AppColors.error;
    } else {
      text = 'Prueba gratuita: ${t.daysLeft} día(s) restantes.';
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.s3,
        children: [
          Text(text, style: TextStyle(color: color, fontSize: AppTextSize.body)),
          ?action,
          if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.error)),
        ],
      ),
    );
  }
}
