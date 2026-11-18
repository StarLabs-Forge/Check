# Prototipo CHECK V1 (datos simulados)

`flutter run -t lib/main_proto.dart` (móvil) · `flutter run -d chrome -t lib/main_proto.dart` (web)

- `buyer/` Comprador: eventos, detalle, entradas, datos, pago QR (15 min), verificando, aprobado/rechazado, consulta por enlace privado.
- `admin/` Administrador y verificador delegado: bandeja, verificación, aprobar/rechazar, avisos, delegación, historial/auditoría.
- `superadmin/` Superadministrador: resumen, locales, eventos, actividad, auditoría (solo lectura).
- `data/proto_store.dart` Estado en memoria compartido entre experiencias.

Sin backend, bancos, pagos ni notificaciones reales. Los QR son de demostración y no son válidos.
