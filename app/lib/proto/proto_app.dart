import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/check_logo.dart';
import 'admin/admin_flow.dart';
import 'buyer/buyer_flow.dart';
import 'data/proto_store.dart';
import 'superadmin/superadmin_flow.dart';
import 'widgets/proto_ui.dart';

/// Prototipo navegable de CHECK V1: comprador, administrador, verificador
/// delegado y superadministrador, con datos simulados.
/// Arranque: `flutter run -t lib/main_proto.dart` (móvil o `-d chrome`).
class ProtoApp extends StatelessWidget {
  const ProtoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'CHECK · Prototipo V1',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: const ExperienceSelector(),
      );
}

class ExperienceSelector extends StatelessWidget {
  const ExperienceSelector({super.key});

  void _open(BuildContext context, ProtoRole r) {
    void exit() => Navigator.of(context).pop();
    final page = switch (r) {
      ProtoRole.buyer => const BuyerHome(),
      ProtoRole.admin => AdminExperience(role: ProtoRole.admin, onExit: exit),
      ProtoRole.verifier => AdminExperience(role: ProtoRole.verifier, onExit: exit),
      ProtoRole.superadmin => SuperadminExperience(onExit: exit),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final cards = <(ProtoRole, IconData, String, String)>[
      (ProtoRole.buyer, Icons.confirmation_number_outlined, 'Comprador', 'Explora eventos, compra sin cuenta, paga por QR bancario y recibe tus entradas.'),
      (ProtoRole.admin, Icons.storefront_outlined, 'Administrador del local', 'Revisa pagos declarados, aprueba o rechaza y delega la verificación.'),
      (ProtoRole.verifier, Icons.verified_user_outlined, 'Verificador delegado', 'Empleado de confianza con permiso solo para verificar pagos.'),
      (ProtoRole.superadmin, Icons.public, 'Superadministrador', 'Supervisión global de locales, eventos, actividad y auditoría.'),
    ];
    return Scaffold(
      body: ResponsiveBody(
        maxWidth: 900,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 16),
          const CheckLogoMark(height: 40),
          const SizedBox(height: 4),
          Text('Prototipo V1 · elige una experiencia', style: ts(AppTextSize.bodyLg, c: AppColors.textSecondary)),
          const SizedBox(height: 12),
          const Notice('Todo es simulado: sin backend, bancos, pagos ni notificaciones reales. Los QR son de demostración y no son válidos. El estado se comparte entre experiencias: compra como comprador y luego aprueba como administrador.'),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 640 ? 2 : 1;
            final w = (c.maxWidth - (cols - 1) * 12) / cols;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (final (r, icon, t, d) in cards)
                SizedBox(
                  width: w,
                  child: PCard(
                    onTap: () => _open(context, r),
                    child: Row(children: [
                      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.accentSubtle, borderRadius: BorderRadius.circular(AppRadius.md)), child: Icon(icon, color: AppColors.accentPrimary)),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t, style: ts(AppTextSize.bodyLg, w: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(d, style: ts(AppTextSize.body, c: AppColors.textSecondary, h: 1.35)),
                      ])),
                      const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    ]),
                  ),
                ),
            ]);
          }),
        ]),
      ),
    );
  }
}
