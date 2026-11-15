import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../data/proto_store.dart';
import '../widgets/proto_ui.dart';
import 'admin_flow.dart';

/// Vista del verificador delegado dentro de la app móvil de staff.
/// Solo ve pagos y su historial; si le revocan el permiso, ve "Acceso denegado".
class VerifierPaymentsScreen extends StatelessWidget {
  const VerifierPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = ProtoStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final allowed = store.verifierEnabled(ProtoStore.verifierActor.id);
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text('Verificar pagos', style: ts(AppTextSize.bodyLg, w: FontWeight.w700)),
              bottom: allowed ? const TabBar(tabs: [Tab(text: 'Pendientes'), Tab(text: 'Mi historial')]) : null,
            ),
            body: !allowed
                ? const StateView(ViewState.denied, message: 'El administrador revocó tu permiso de verificación de pagos.')
                : TabBarView(children: [
                    PaymentsInbox(actor: ProtoStore.verifierActor),
                    HistoryPage(actor: ProtoStore.verifierActor, onlyMine: true),
                  ]),
          ),
        );
      },
    );
  }
}
