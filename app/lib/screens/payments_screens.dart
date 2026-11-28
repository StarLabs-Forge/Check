import 'package:flutter/material.dart';

import '../proto/admin/admin_flow.dart';
import '../proto/data/proto_store.dart';
import '../proto/admin/staff_accounts_page.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_scaffold.dart';
import '../widgets/payment_cutoff_alert.dart';

/// Pagos por verificar — dentro del panel Admin real (mismo sidebar/drawer,
/// sesión y responsive que Dashboard/Eventos/Tickets).
class AdminPaymentsScreen extends StatelessWidget {
  const AdminPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) => AdminScaffold(
        current: AdminRoute.pagos,
        body: Column(
          children: [
            const Padding(padding: EdgeInsets.symmetric(horizontal: AppSpacing.s6), child: PaymentCutoffAlert()),
            Expanded(child: PaymentsInbox(actor: ProtoStore.admin)),
          ],
        ),
      );
}

/// Verificadores de confianza (delegación del permiso de verificar pagos).
class AdminVerifiersScreen extends StatelessWidget {
  const AdminVerifiersScreen({super.key});

  @override
  Widget build(BuildContext context) => const AdminScaffold(
        current: AdminRoute.verificadores,
        body: DelegationPage(),
      );
}

/// Historial / auditoría de verificaciones del local.
class AdminAuditScreen extends StatelessWidget {
  const AdminAuditScreen({super.key});

  @override
  Widget build(BuildContext context) => AdminScaffold(
        current: AdminRoute.auditoria,
        body: HistoryPage(actor: ProtoStore.admin, onlyMine: false),
      );
}

/// Personal: crear cuentas (correo + contraseña) y asignar permisos.
class AdminStaffScreen extends StatelessWidget {
  const AdminStaffScreen({super.key});

  @override
  Widget build(BuildContext context) => const AdminScaffold(
        current: AdminRoute.personal,
        body: StaffAccountsPage(),
      );
}
