import 'dart:async';

import 'package:flutter/material.dart';

import '../data/admin_repository.dart';
import '../theme/app_theme.dart';

/// Aviso al administrador: pagos informados sin revisar pasadas las 10:00 del día
/// del evento. Solo avisa: no anula pedidos ni libera cupos. La hora de corte la
/// calcula el servidor (`payment_cutoff_alerts`).
class PaymentCutoffAlert extends StatefulWidget {
  const PaymentCutoffAlert({super.key, this.load, this.onReview});

  /// Inyectable para pruebas; por defecto usa [AdminRepository].
  final Future<List<CutoffAlert>> Function()? load;

  /// Si se indica, muestra el botón «Revisar pagos».
  final VoidCallback? onReview;

  @override
  State<PaymentCutoffAlert> createState() => _PaymentCutoffAlertState();
}

class _PaymentCutoffAlertState extends State<PaymentCutoffAlert> {
  List<CutoffAlert> _alerts = const [];
  bool _failed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final alerts = await (widget.load ?? AdminRepository.instance.paymentCutoffAlerts)();
      if (mounted) setState(() { _alerts = alerts; _failed = false; });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed && _alerts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: AppSpacing.s3),
        child: Text('No pudimos comprobar los pagos pendientes del corte de las 10:00.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.caption)),
      );
    }
    if (_alerts.isEmpty) return const SizedBox.shrink();
    final total = _alerts.fold<int>(0, (s, a) => s + a.pending);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppSpacing.s4),
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.bgDanger,
        border: Border.all(color: AppColors.error),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$total pago(s) sin revisar: pasó el corte de las 10:00 del día del evento',
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.s2),
          for (final a in _alerts)
            Text('${a.eventName}: ${a.pending} pendiente(s)',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.body)),
          const SizedBox(height: AppSpacing.s2),
          const Text('Los cupos siguen reservados hasta que apruebes o rechaces cada pago.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.caption)),
          if (widget.onReview != null) TextButton(onPressed: widget.onReview, child: const Text('Revisar pagos')),
        ],
      ),
    );
  }
}
