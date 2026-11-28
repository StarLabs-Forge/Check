<p align="center">
  <img src="app/assets/branding/check_logo_horizontal.svg" alt="CHECK" width="360">
</p>

# CHECK

Plataforma de operaciones para locales y organizadores de eventos (La Paz, Bolivia): venta de
entradas con pago verificado manualmente, un QR por persona y control de acceso en puerta.

**Objetivo:** que el local publique eventos, venda y controle el ingreso sin pasarelas de pago,
con inventario consistente y trazabilidad de cada decisión.

## Estado (27/11/2026)

> **Nada de lo nuevo está desplegado en producción.** El proyecto principal de Supabase tiene las
> migraciones hasta la 13. Las migraciones 14–22 están validadas solo en el proyecto temporal
> `CHECK-DEV`. Plan: [docs/despliegue.md](docs/despliegue.md).

| Funcionalidad | Estado |
|---|---|
| Reglas de eventos, borrador, QR en borrador | Validado en Supabase DEV (SQL) · pendiente de despliegue |
| Categorías, cupos, aforo, precios históricos, eliminación | Validado en Supabase DEV (SQL) · pendiente de despliegue |
| Máximo 3 pedidos activos por teléfono y sin sobreventa | Validado en Supabase DEV con solicitudes HTTP simultáneas |
| Prueba de 14 días, restricciones comerciales, planes | Validado en Supabase DEV (SQL) · interfaz probada con widgets |
| MFA TOTP exigido en la base y recuperación | Validado en Supabase DEV con sesiones simuladas · **falta prueba con autenticador real** · migración 21 pendiente de aprobación |
| Registro con código OTP | Implementado · **falta configurar la plantilla y validar con un correo real** |
| Google OAuth | Implementado · **pendiente de validación manual** |
| Avisos de vencimiento | Panel implementado, cola probada · **envío por correo pendiente (sin proveedor)** |
| Demo | Validada con pruebas · **sin despliegue público** |

## Arquitectura

| Pieza | Tecnología | Carpeta |
|---|---|---|
| App única: comprador, administrador del local, staff y superadministrador | Flutter 3.38 (Web, Android, iOS) | `app/` |
| Backend | Supabase: Auth, PostgreSQL con RLS, RPC `SECURITY DEFINER`, triggers, Realtime, `pg_cron`, Edge Functions (Deno) | `supabase/` |
| Sitio público | HTML, CSS y JavaScript estáticos (**no usa npm**: no hay `package.json`) | `website/` |

Las reglas de negocio se exigen en la base (triggers, RLS y funciones); la interfaz solo las
explica. No hay servidor intermedio ni pasarela de pago.

```
app/
  lib/        config · data · services · screens · widgets · staff · proto (comprador y superadmin)
  env/        dev.example.json (copia a dev.json, ignorado por git)
  test/       unitarias, de widgets y demo
supabase/
  migrations/ 01 … 22 (ver tabla)
  functions/  create-staff · create-venue · mfa-reset
  tests/      regresión SQL e integration/ (concurrencia por HTTP)
website/      sitio y tests/ de navegador
docs/         reglas, despliegue, configuración de Auth, super admin
```

## Instalación y ejecución

Requisitos: Flutter 3.38+, y para las pruebas de integración y navegador Python 3.10+, Node 22+ y
Edge o Chrome.

```bash
cd app
flutter pub get

flutter run -d chrome --dart-define=DEMO=true                  # demo, sin backend
flutter run -d chrome --dart-define-from-file=env/dev.json     # desarrollo (CHECK-DEV)
flutter run -d chrome                                          # producción

flutter build web [--dart-define=DEMO=true | --dart-define-from-file=env/dev.json]

# Sitio público (estático)
python -m http.server 8000 --directory website
```

### Entornos y variables (`--dart-define`)

| Entorno | Variables | Notas |
|---|---|---|
| Demo | `DEMO=true` | **No inicializa Supabase**: datos simulados, sin límite de tiempo, no activa pruebas. Cuentas `admin@demo.com`, `staff@demo.com`, `super@demo.com` (cualquier contraseña) |
| Desarrollo | `APP_ENV=dev`, `SUPABASE_URL`, `SUPABASE_ANON_KEY` | En `app/env/dev.json`. Muestra la cinta «DEV». La app no arranca si apunta a producción |
| Producción | `APP_ENV=prod` (por defecto) | URL y clave publicable por defecto en `supabase_config.dart` |

Las claves *publishable* son públicas por diseño. **Nunca** pongas la `service_role` en la app ni
en el repositorio.

## Migraciones

| # | Contenido | Producción | CHECK-DEV |
|---|---|---|---|
| 01–05, 06–13, 10a, 10b | Esquema base, pedidos, staff, ajustes, superadmin | Aplicadas | Replicadas (esquema idéntico) |
| 14 | Auditoría de estados, prueba, categorías | Pendiente | Validada |
| 15 | Revoca el `UPDATE` directo del estado (**aplicar al final**) | Pendiente | Validada |
| 16 | Teléfono normalizado | Pendiente | Validada |
| 17 | Reglas de borrador y QR en borrador | Pendiente | Validada |
| 18 | Inventario, aforo, auditoría de categorías | Pendiente | Validada |
| 19 + 22 | Prueba por local, planes, restricciones, avisos | Pendiente | Validadas |
| 20 | MFA exigido y recuperación | Pendiente | Validada |
| 21 | Revocar sesiones al restablecer MFA | Pendiente | **No aplicada: requiere aprobación** |

Interruptores de despliegue en `platform_settings` (apagados por defecto): `commercial_gate`
(restricciones comerciales) y `mfa_required`.

## Autenticación, roles y permisos

- **Roles** (tabla `profiles`, no escribibles por el cliente): `super_admin` (plataforma, sin
  datos de compradores ni personal), `admin` (local), `staff` (permisos `scanQr`,
  `verifyPayments`, `viewGuests`, `createTickets`, `viewEvents`). El comprador es anónimo y
  consulta su pedido con un token. El registro público solo crea `admin`.
- **Inicio de sesión:** selector de tipo de usuario → credenciales → rol real → panel.
  **Registro:** formulario → código OTP → datos pendientes → panel. Con sesión activa, `/registro`
  lleva al panel.
- **Contraseñas:** mínimo 8, frases permitidas.
- **MFA:** administradores y superadministradores usan TOTP (`/mfa`). La base exige `aal2`, un
  factor vigente y un código posterior al último restablecimiento.
- **OTP, SMTP, MFA y Google OAuth** (pasos exactos): [docs/configuracion-auth.md](docs/configuracion-auth.md).
- **Recuperación de MFA:** [docs/super-admin.md](docs/super-admin.md).

## Reglas de negocio (resumen)

Detalle y las 22 decisiones aprobadas: [docs/reglas-negocio-v1.md](docs/reglas-negocio-v1.md).

- **Locales:** el administrador completa nombre y datos de cobro. El superadministrador crea
  locales con prueba (sin iniciarla) o con plan verificado, y puede suspenderlos.
- **Eventos:** `borrador → activo → en vivo → finalizado` (`activo → borrador` y
  `activo → finalizado`). Volver a borrador exige motivo y no tener ventas ni ingresos; las
  reservas siguen su curso. Todo cambio queda en `event_status_log`.
- **Categorías e inventario:** la suma de cupos no supera el aforo; un cupo no baja de lo
  comprometido; precios históricos intactos; cambios en `ticket_type_log`; solo se elimina una
  categoría sin historial. Toda entrada manual pertenece a una categoría.
- **Órdenes y reservas:** 15 minutos desde el servidor; pago informado conserva cupo; rechazo
  libera; máximo 3 pedidos activos por teléfono; el importe lo calcula el servidor.
- **Control de acceso:** un QR por persona, sin reingreso; en borrador no se admite ni se consume.
  **La validación es solo en línea: no hay operación offline.**
- **Prueba gratuita:** 14 días, activación manual, una por local. Sin prueba ni plan: preparar en
  borrador, sin publicar ni vender. Al vencer: no hay publicaciones ni ventas nuevas, pero se
  resuelven pagos, se controlan accesos y se conservan los datos.
- **Avisos:** 7, 3, 1 días y al vencer (panel; correo pendiente).
- **Planes:** el superadministrador los activa tras verificar el pago; no hay cobro automático.
  El sitio publica Starter Bs 150, Pro Bs 350 y Local Premium Bs 600 al mes; en la base
  `plan_limits.price_bs` sigue en 0 y la app no muestra precios.

## Pruebas

| Comando | Qué cubre | Último resultado (27/11/2026) |
|---|---|---|
| `cd app && flutter analyze` | Análisis estático | Sin hallazgos |
| `flutter test` | Unitarias y de widgets (con dobles) | 55 aprobadas, 45 omitidas por requerir demo |
| `flutter test --dart-define=DEMO=true` | Lo anterior y suites demo | 82 + 18 aprobadas en dos corridas (4 archivos superaron el tiempo de compilación en la primera) |
| `supabase/tests/18_events_inventory.sql` | Eventos, inventario, expiración (SQL real) | 50/51; el fallo era de la prueba, corregida y verificada aparte |
| `supabase/tests/19_trial_commercial.sql` | Prueba, restricciones, planes, avisos | 47/48; llevó a la migración 22, verificada aparte |
| `supabase/tests/20_mfa_isolation.sql` | MFA, recuperación, aislamiento entre locales | 55/55 |
| `python supabase/tests/integration/concurrency_orders.py` | Concurrencia real por HTTP | 5/5 |
| `python supabase/tests/integration/api_security.py` | API pública anónima: tablas, funciones, Edge Functions | 8/9; el fallo (`mfa-reset` respondía 400 antes de 401) se corrigió y redesplegó |
| `node website/tests/navigation.mjs` | Sitio en navegador real | Ver informe de la entrega |

Las pruebas SQL se ejecutan **solo en un proyecto de desarrollo** (editor SQL); terminan en una
excepción `RESULTS: …` que revierte todo. `14_status_audit_trial.sql` es histórica. La de
concurrencia necesita en dev dos eventos `Fixture Concurrencia 1/2` (aforo 100, categorías
«General» 60 y «Cinco» 5), ya creados en `CHECK-DEV`.

No hay integración continua ni pruebas de extremo a extremo con sesiones reales.

## Pendiente y limitaciones conocidas

- Aprobar la migración 21; configurar OTP, SMTP, contraseña mínima y Google en los paneles.
- Proveedor de correo para OTP a usuarios reales y avisos de vencimiento.
- Despliegue público de la demo: los botones «Solicitar demo» del sitio apuntan a
  `check-starlabs3.vercel.app`, que hoy muestra el inicio de sesión de Vercel.
- La app real está en `check-demo-three.vercel.app` (nombre de proyecto engañoso).
- Sin implementar: corte de las 10:00 (falta definirlo), ventas presenciales por staff, cierre de
  caja, operación offline, pantalla de ingreso manual, carga masiva CSV, recuperación de
  contraseña.
- Protección contra contraseñas filtradas: requiere plan Pro de Supabase.
- El menú de secciones del sitio se oculta en móvil (diseño actual).

## Despliegue, recuperación y entorno temporal

Orden de migraciones, compatibilidad, reversión, pruebas posteriores y eliminación de
`CHECK-DEV` (`xcvmdtaxymuvudppmqjs`, solo con confirmación): [docs/despliegue.md](docs/despliegue.md).

---

Visión de integración futura: [docs/vision-clandest.md](docs/vision-clandest.md) · CHECK — La Paz, Bolivia
