# CHECK V1 · Reglas de negocio y seguridad aprobadas

Referencia para cualquier cambio futuro. Aprobadas el 27/11/2026. Si una implementación
contradice este documento, manda este documento y el cambio debe registrarse aquí.

**Estado:** `BD` = exigida en la base (CHECK-DEV) · `App` = interfaz implementada ·
`Pendiente` = ver la columna de notas. Nada está desplegado en producción todavía.

## Decisiones aprobadas (22)

| # | Decisión | Dónde se exige | Estado y notas |
|---|---|---|---|
| 1 | La prueba gratuita (14 días) se **activa manualmente**; pertenece al local y se usa una sola vez | `start_trial`, `venue_trials` (migraciones 14, 19) | BD + App |
| 2 | El superadministrador asigna **prueba** (no la inicia) o **plan contratado** | `superadmin_assign_trial` / `superadmin_assign_plan`, `create-venue` | BD + App |
| 3 | Al vencer: **bloqueo comercial**, sin cerrar el panel ni borrar datos | Triggers de la migración 19 | BD + App. Activar con `platform_settings.commercial_gate` |
| 4 | Avisos de vencimiento (7, 3, 1 días y al vencer) en el **panel y por correo** | `trial_notifications`, tarea `pg_cron` | Panel: App. **Correo pendiente: falta proveedor de envío** |
| 5 | Volver de activo a borrador solo **sin ventas ni QR usados**; reservas pendientes permitidas; motivo obligatorio | `private.require_status_reason` (migración 17) | BD + App |
| 6 | Las reservas conservan sus 15 minutos; los pagos informados se resuelven aun en borrador; aprobar no reactiva | `declare_payment`, `decide_order` | BD |
| 7 | **Demo ilimitada** y aislada: no inicializa Supabase ni activa pruebas | Build `DEMO=true` | App. **Falta un despliegue público de la demo** |
| 8 | Seguridad reforzada con MFA | Migraciones 20–21 | BD + App. Activar con `platform_settings.mfa_required` |
| 9 | Antes de activar la prueba: configurar y preparar en borrador; **no** publicar, vender, emitir ni controlar accesos | Migración 19 | BD + App |
| 10 | Los QR emitidos en borrador **solo permiten ingresar con el evento activo** y no se consumen antes | `validate_qr`, `confirm_checkin` (17) | BD + App |
| 11 | Contraseñas de **mínimo 8** caracteres, frases permitidas, sin caducidad | App y Edge Functions; mínimo en Supabase Auth | App. **Configurar el mínimo en el panel.** Protección de contraseñas filtradas: requiere plan Pro |
| 12 | **MFA TOTP** obligatorio para administradores y superadministradores, **condicionado a OTP validado** | `private.mfa_ok` + políticas restrictivas | BD + App, apagado hasta validar el OTP |
| 13 | Recuperación del administrador **solo por el superadministrador**, auditada y con revocación de sesiones | `superadmin_authorize_mfa_reset`, `mfa-reset` | BD + App (migración 21 aplicada en dev) |
| 14 | Recuperación del superadministrador **manual por el propietario** del proyecto Supabase | `docs/super-admin.md` | Documentado |
| 15 | La emisión manual exige **categoría** y descuenta cupo | `create_ticket` + triggers (18) | BD + App |
| 16 | Un precio nuevo aplica **solo a pedidos nuevos**; cambios auditados | `order_lines.unit_price`, `tickets.unit_price`, `ticket_type_log` | BD |
| 17 | Cupos: nunca por debajo de lo vendido + reservado; la suma no supera el aforo | Triggers (18) | BD |
| 18 | Desactivar una categoría no perjudica operaciones existentes | `active` (14, 18) | BD + App |
| 19 | Solo se elimina una categoría **sin historial** | `private.guard_ticket_type_delete` | BD + App |
| 20 | Retención de 15 minutos controlada por el servidor, sin pausas | `orders.expires_at` | BD |
| 21 | Los planes se activan por **aprobación manual** del superadministrador | `venue_subscriptions` | BD + App. Sin precios ni duraciones inventados |
| 22 | Entorno temporal gratuito de Supabase, eliminado al final **previa confirmación** | `CHECK-DEV` | Creado. Ver `docs/despliegue.md` |

## Reglas V1 que se conservan

Sin pasarelas de pago · pagos únicos y completos · sin parciales ni devoluciones · un QR por
persona · retención de 15 minutos · máximo de entradas por pedido configurable (hoy por
categoría) · **máximo 3 pedidos activos por teléfono en toda la plataforma** (normalizado:
`+591`, `00591` y `0` inicial equivalen) · pago informado conserva cupo · rechazo libera al
instante · sin recuperar pedidos rechazados · nombre, teléfono y CI obligatorios, correo
opcional · solo personal autorizado registra ingresos · sin reingreso.

## Entrada a la app (definido el 28/11/2026)

La app abre directamente en el registro, con acceso a «Inicia sesión»; se retiraron los
selectores de comprador/local y de web/móvil (sustituye al requisito anterior de elegir tipo de
usuario). Los compradores entran desde el sitio web. Los eventos de referencia del sitio se
conservan como simulación.

## Corte de las 10:00 (definido el 28/11/2026)

A las 10:00 del día del evento (hora de Bolivia), si quedan pagos informados sin revisar,
**solo se avisa al administrador** en el panel (`payment_cutoff_alerts`, migración 23). No se
anulan pedidos, no se liberan cupos y se puede aprobar o rechazar después. Sin aviso por correo.

## Reglas citadas que aún NO existen en el código

No se implementaron porque requieren definición o están fuera de lo entregado; no las des por
cumplidas:

| Regla | Situación |
|---|---|
| Ventas presenciales y cobro por staff autorizado | No hay flujo de venta presencial; `create_ticket` solo lo usa el administrador |
| Cierre de caja y justificación de diferencias | No implementado |
| Operación offline, cupos preasignados, sincronización e incidencias | No implementado: la validación de QR es **solo en línea** (sin conexión no se valida nada) |
| Ingreso manual sin QR con auditoría | Existe `confirm_checkin` en la base; sin pantalla específica |

## Interpretaciones aplicadas (revisables)

- «Entradas vendidas» = pedido aprobado, o entrada con pedido, o entrada manual **pagada** de un
  evento de pago. Las entradas manuales «por cobrar» y las invitaciones de eventos gratuitos no
  impiden volver a borrador (sí si ya se usaron).
- Tras vencer la prueba o terminar un plan se mantiene el control de accesos; solo se bloquea a
  un local que nunca tuvo prueba ni plan.
- Iniciar («en vivo») un evento ya publicado está permitido tras el vencimiento; publicar un
  borrador no.
- Los permisos de emisión no cambiaron: solo el administrador emite entradas manuales.
