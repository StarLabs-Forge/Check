import 'package:flutter/material.dart';

import '../proto/admin/admin_flow.dart';
import '../proto/data/proto_store.dart';
import '../widgets/admin_scaffold.dart';

/// Pagos por verificar — dentro del panel Admin real (mismo sidebar/drawer,
/// sesión y responsive que Dashboard/Eventos/Tickets).
class AdminPaymentsScreen extends StatelessWidget {
  const AdminPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) => AdminScaffold(
        current: AdminRoute.pagos,
        body: PaymentsInbox(actor: ProtoStore.admin),
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
