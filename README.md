# CHECK

### CHECK — Plataforma de Operaciones para Venues y Eventos en Tiempo Real

> Sistema de gestión para locales y organizadores de eventos — La Paz, Bolivia

![Estado](https://img.shields.io/badge/estado-MVP%20%2F%20Concepto-E63950)
![Plataforma](https://img.shields.io/badge/plataforma-Web%20%2B%20Mobile-1A1A2E)
![Flutter](https://img.shields.io/badge/mobile-Flutter-02569B)
![React](https://img.shields.io/badge/web-React-61DAFB)
![Supabase](https://img.shields.io/badge/backend-Supabase-3ECF8E)

---

## Estado real de la implementación (verificado)

> Esta sección describe lo que existe **hoy** en el repositorio y prevalece sobre las secciones de concepto/MVP de más abajo (p. ej. el panel Admin **no** es React: todo el producto de aplicación es una única app Flutter).
> Nota de mantenimiento: la primera línea de este archivo contiene, pegada antes del título, la salida de un `npm run dev` fallido. Es una modificación sin commitear del autor del repo y se preservó tal cual; conviene que la limpie quien la hizo.

### Arquitectura

| Pieza | Tecnología | Ubicación |
|---|---|---|
| App (comprador, Admin del local, Staff, Superadmin) | Flutter 3.38 — Web, Android, iOS | `app/` |
| Backend | Supabase: Auth, PostgreSQL + RLS, RPC `SECURITY DEFINER`, Realtime, Edge Functions (`create-staff`, `create-venue`) | `supabase/` |
| Sitio público | HTML/CSS/JS estático | `website/` |

Reglas V1 aplicadas en la base (no en el cliente): QR único por persona, reserva de 15 min, pedidos con pago informado conservan cupo, rechazo/expiración liberan cupo, máximo 3 pedidos activos por teléfono (normalizado, toda la plataforma), sin pasarelas ni devoluciones.

### Variables de entorno (`--dart-define`)

| Variable | Uso |
|---|---|
| `SUPABASE_URL`, `SUPABASE_ANON_KEY` | Proyecto Supabase (la *publishable key* es pública por diseño; **nunca** pongas la `service_role`). Hay valores por defecto del proyecto actual. |
| `DEMO=true` | Build de demostración: **no inicializa Supabase**, usa datos simulados (`admin@demo.com`, `staff@demo.com`, `super@demo.com`). |

### Ejecución local

```bash
cd app
flutter pub get
flutter run -d chrome                          # contra Supabase
flutter run -d chrome --dart-define=DEMO=true  # demo, sin backend
flutter build web
```

### Pruebas

| Comando (desde `app/`) | Qué ejecuta |
|---|---|
| `flutter analyze` | Análisis estático |
| `flutter test` | Unitarias y de componentes. Las que dependen de la demo se **omiten declarando el motivo** (`test/demo_only.dart`) |
| `flutter test --dart-define=DEMO=true` | Lo anterior + suites demo (flujos del store simulado, ajuste a pantalla, permisos de staff demo) |
| `supabase/tests/14_status_audit_trial.sql` | Regresión SQL de la migración 14; **debe ejecutarse en una rama/entorno aislado** (termina en `ROLLBACK`) |

No existen todavía pruebas de integración automáticas contra Supabase ni E2E de navegador en CI.

### Migraciones

Aplicadas en el proyecto `check`: `20261001_*` … `20261122_13_superadmin_platform`.

**Pendientes de aplicar (no desplegadas):**
- `20261127_14_status_audit_trial_categories.sql` — auditoría de estados (`event_status_log`, `set_event_status`), prueba de 14 días (`venue_trials`, `start_trial`, `trial_status`), categorías (`description`, `active`, `ticket_type_stats`, guarda de cupo), `venue_id` en `public_events`, límite por teléfono en `create_order`.
- `20261127_15_enforce_status_rpc.sql` — revoca el UPDATE directo de `events.status`. Orden: 14 → publicar la app → 15. Recuperación: `grant update (status) on public.events to authenticated;`.

Procedimiento recomendado: crear una rama de Supabase, aplicar 14, ejecutar `supabase/tests/14_status_audit_trial.sql` (esperado en su cabecera), probar la app contra la rama, luego aplicar 14 en el proyecto principal, publicar la app y por último 15. La app tolera 14 ausente (cae al UPDATE directo y oculta el banner de prueba) hasta que 15 se aplique.

### Roles

`super_admin` (plataforma, sin acceso a compradores ni pagos), `admin` (local), `staff` (permisos por cuenta: `scanQr`, `verifyPayments`, `viewGuests`, `createTickets`, `viewEvents`), comprador anónimo (RPC con token de pedido). El rol sale de `profiles` en la base; las columnas `role/plan/status` no son escribibles por el cliente. El registro público solo crea `admin`.

### Autenticación

- Registro con correo (con o sin confirmación), cuenta existente (respuesta anti-enumeración detectada en `AuthService.isObfuscatedExistingUser`), login por selector de plataforma, Google OAuth, perfil incompleto → `/completar-perfil`.
- **Google OAuth**: habilitar el proveedor en Supabase → Authentication → Providers → Google y registrar las Redirect URLs (origen web y `io.supabase.check://login-callback/`).

### Funcionalidades

| Funcionalidad | Estado |
|---|---|
| Catálogo del comprador por local real (`venues.id`), refresco cada 60 s | Implementado; **pendiente de despliegue** (migración 14) |
| Categorías de entrada: UI de gestión, cifras vendidas/reservadas/disponibles | Implementado; pendiente de despliegue; sin validar contra Supabase |
| Auditoría de estados de evento y motivo obligatorio | Implementado; **pendiente de despliegue y de validación en entorno aislado** |
| Prueba gratuita de 14 días | Implementado en servidor + banner (probado con widget tests); pendiente de despliegue |
| Límite de 3 pedidos activos por teléfono | Implementado; pendiente de despliegue |
| Pedidos, pagos, verificadores, auditoría, staff, superadmin | Desplegado (migraciones 06–13) |
| Demo aislada (build `DEMO`) | Implementado y probado en la suite demo |
| Registro, login, Google OAuth contra Supabase real | Implementado; **sin validar de extremo a extremo** (Google requiere interacción manual) |
| Navegación web / responsive en navegador | Build web (demo) compila; **validación en navegador real bloqueada** (extensión de Chrome no conectada); solo pruebas de widget |

### Limitaciones y decisiones de negocio pendientes

- La migración 14 y la 15 no están aplicadas ni validadas en una base aislada.
- Prueba gratuita: mecanismo de activación (hoy botón manual, una vez), restricciones al vencer, notificación por correo y cobro quedan **sin definir**; no se bloquea nada al vencer.
- Duración y límites comerciales de la demo: sin definir.
- ¿Qué ocurre con pagos informados si un evento vuelve a borrador? Hoy siguen pudiendo aprobarse; solo se exige motivo y queda auditado.
- Protección contra contraseñas filtradas desactivada (ajuste del panel de Supabase Auth).
- Entradas emitidas manualmente (`create_ticket`) no descuentan del cupo por categoría (`held_seats` cuenta solo pedidos).
- El wordmark del sidebar, auth y staff sigue la especificación de Figma (texto), no el SVG horizontal.

---

## ¿Qué es CHECK?

CHECK digitaliza y centraliza el control de acceso y el manejo de entradas para locales nocturnos, bares, clubs y organizadores de eventos independientes.

El **QR es el eje central**: cada entrada genera un código único que el cliente recibe y presenta en puerta. El staff escanea el QR y obtiene al instante el estado — pagado, pendiente de cobro, o inválido — con el dashboard del organizador actualizándose en tiempo real.

> **CHECK opera como producto independiente.** Tiene su propia base de datos y autenticación. En una versión futura se integrará con [CLANDEST](#integración-futura-con-clandest) para ofrecer un ecosistema completo. Ver sección al final.

---

## El problema que resuelve

- Control de acceso manual y propenso a errores (listas en papel, conteo a mano)
- Sin visibilidad en tiempo real de cuántos ingresaron vs. confirmados
- Dificultad para delegar el control de puerta al staff sin perder visibilidad
- Sin historial de eventos para análisis posterior

---

## Alcance del MVP

El MVP de CHECK está deliberadamente acotado a **5 funcionalidades core**. Todo lo demás (gestión de mesas, multi-venue, importación CSV, plano de sala, etc.) queda en [Post-MVP / Roadmap](#post-mvp--roadmap) para validar lo esencial antes de sumar complejidad operativa.

| # | Funcionalidad | Descripción |
|---|---|---|
| 1 | Autenticación con roles | Dueño/Organizador y Staff. Staff solo ve eventos asignados. |
| 2 | Creación de eventos | Alta de evento con datos básicos y capacidad. |
| 3 | Generación de token QR | Token único firmado por entrada/invitado. |
| 4 | Escaneo QR en tiempo real | Staff escanea, sistema valida y actualiza asistencia al instante. |
| 5 | Dashboard en vivo | Organizador ve el conteo de ingresos actualizarse en tiempo real. |

**Fuera del MVP explícitamente:** gestión de mesas, soporte multi-venue por admin, plano de sala, importación CSV, reportes históricos.

---

## Stack tecnológico

| Capa | Tecnología | Uso |
|---|---|---|
| App Móvil (Staff) | Flutter (iOS + Android) | Check-in en puerta. Escaneo de QR nativo. Baja conectividad. |
| Web Dashboard (Admin) | React | Panel de administración en tiempo real. |
| Sitio web (Landing) | HTML / CSS / JS estático | Sitio público de marketing. Sin SSR — no lo necesita en esta etapa. |
| Backend | Supabase (Edge Functions) | Lógica de negocio: generación y validación de QR. Sin capa Node/Express intermedia. |
| Base de Datos | Supabase (PostgreSQL) | Tablas, RLS por rol, funciones y triggers. |
| Autenticación | Supabase Auth + JWT | Roles: Admin y Staff. Staff solo ve eventos asignados. |
| Tiempo Real | Supabase Realtime | Dashboard actualizado en vivo durante el evento. |
| Generación de QR | pgcrypto (función SQL) | Token único de 32 bytes firmado, generado directamente en Postgres. |
| Almacenamiento | Supabase Storage | Imágenes de QR para descarga y envío al cliente. |

> **Nota de arquitectura:** se eliminó la capa Node.js/Express del diseño original. Supabase cubre autenticación, base de datos, funciones (RPC/Edge Functions) y tiempo real sin necesidad de un backend intermedio — esto reduce infraestructura a mantener, deploys y superficie de ataque, alineado con el objetivo de simplicidad operativa y costo bajo para el MVP.

---

## Estructura del proyecto

```
check/
  app/                      # App Flutter (móvil + Flutter Web)
    lib/
    android/
    ios/
    web/                    # Target web de Flutter (no el sitio estático)
  website/                  # Sitio estático HTML / CSS / JS
    index.html
    css/
    js/
  backend/                  # API Node.js + Express (pendiente)
  docs/                     # Especificación de producto, wireframes
```

---

## Usuarios del sistema

### Admin (Dueño del local / Organizador)
Acceso completo. Crea eventos, genera QR, ve el dashboard en tiempo real y administra al staff.

### Staff / Portero
Acceso restringido a los eventos asignados. Escanea QR, ve el resultado al instante, confirma cobros en puerta y busca invitados por nombre como respaldo.

---

## Flujo principal

```
Admin crea evento
  → registra invitado/entrada
    → sistema genera QR único firmado
      → admin envía QR al cliente (WhatsApp, etc.)
        → cliente presenta QR en puerta
          → staff escanea con app móvil
            → sistema responde con estado:
                VERDE    — pagado, ingresa directo
                AMARILLO — cobrar en puerta, confirmar
                ROJO     — inválido / ya usado / cancelado
                  → log registrado con timestamp y staff_id
                    → dashboard del admin se actualiza en vivo
```

---

## Estados de QR en puerta

Cada estado usa **color + forma** de manera redundante (checkmark, X, triángulo de advertencia) — en un entorno de puerta con poca luz, el color solo no es suficiente para una lectura confiable y rápida por parte del staff.

| Estado | Color | Ícono | Acción del staff |
|---|---|---|---|
| Entrada pagada | 🟢 VERDE | ✓ | Ingresa directo. |
| Entrada pendiente de pago | 🟡 AMARILLO | ⚠ | Cobra en puerta. Confirma en el sistema. |
| QR ya utilizado | 🔴 ROJO | ✕ | Escaneado anteriormente. No permite reingreso. |
| QR inválido / no encontrado | 🔴 ROJO | ✕ | No corresponde a ninguna entrada del evento. |
| Sin QR (búsqueda manual) | ⚫ GRIS | — | Staff busca por nombre en la lista. |

---

## Módulos (MVP)

- **Gestión de Eventos** — crear, editar. Estados: Borrador → Activo → En curso → Finalizado
- **Entradas / Invitados** — registro, generación de QR, envío al cliente
- **Check-in (App Staff)** — escaneo QR nativo, resultado visual, cobro en puerta, búsqueda manual
- **Dashboard** — contadores en vivo, feed de ingresos
- **Gestión de Staff** — cuentas, asignación a eventos

---

## Acceso a datos (Supabase)

CHECK no expone una API REST custom. El acceso a datos ocurre por dos vías, ambas sobre Supabase:

### 1. PostgREST autogenerado
Cada tabla queda expuesta automáticamente como endpoint REST, con **Row Level Security (RLS)** aplicando el control de acceso por rol (admin ve solo sus eventos, staff ve solo eventos asignados). No requiere código de backend adicional para operaciones CRUD estándar (crear evento, listar entradas, etc.).

### 2. Funciones RPC / Edge Functions
La lógica de negocio que no es CRUD simple vive en funciones de Postgres o Edge Functions, invocadas vía `supabase.rpc(...)`:

| Función | Descripción |
|---|---|
| `generate_qr_token()` | Genera un token único de 32 bytes firmado con pgcrypto al crear una entrada. |
| `validate_qr(token, event_id)` | Valida un QR escaneado y retorna el estado completo (pagado / pendiente / inválido / usado). |
| `confirm_checkin(token, staff_id)` | Confirma el ingreso o cobro en puerta y registra el log. |

### 3. Realtime
El dashboard se suscribe a cambios en la tabla de entradas vía Supabase Realtime — no hay polling ni endpoint de "resumen" separado; el estado se actualiza por evento (push), no por consulta periódica.

---

## Base de datos

El schema completo está en `supabase/schema.sql`. Incluye tablas, enums, RLS, funciones y triggers listos para ejecutar en Supabase.

### Tablas del MVP

| Tabla | Descripción |
|---|---|
| `profiles` | Extiende auth.users. Rol (admin / staff), nombre, teléfono. |
| `events` | Eventos del admin. Tipo de acceso, capacidad, estado. |
| `event_staff` | Asignación de staff a eventos específicos. |
| `tickets` | Entradas individuales. QR único, estado de pago y check-in. |
| `scan_logs` | Log inmutable de cada escaneo: staff, resultado, timestamp. |

### Tablas diferidas a Post-MVP

| Tabla | Se activa cuando |
|---|---|
| `venues` | Se habilite soporte multi-local por admin. |
| `table_zones` | Se habilite gestión de mesas. |
| `reservations` | Se habilite gestión de mesas. |
| `tables` | Se habilite gestión de mesas. |

> Estas tablas ya estaban diseñadas en el schema original y se mantienen documentadas, pero **no se crean/activan en el MVP** — evitar sincronización de estado de mesas y multi-venue reduce superficie de bugs y tiempo de desarrollo antes de validar el core del producto con el piloto.

---

## Post-MVP / Roadmap

Funcionalidad explícitamente fuera del MVP, ordenada por prioridad esperada una vez validado el core:

| Fase | Entregable |
|---|---|
| **Post-MVP 1** | Gestión de mesas — zonas, estado en tiempo real, reservas |
| **Post-MVP 2** | Soporte multi-venue por admin |
| **Post-MVP 3** | Importación CSV de listas de invitados |
| **Post-MVP 4** | Plano de sala interactivo |
| **Post-MVP 5** | Reportes históricos y analíticas por evento |
| **Futuro** | Integración con CLANDEST (ver sección abajo) |

---

## Fases de desarrollo (MVP)

| Fase | Duración | Entregables |
|---|---|---|
| **Fase 0 — Fundación** | 2 semanas | Schema Supabase (tablas MVP) · RLS por rol · Auth (admin/staff) · Función `generate_qr_token()` |
| **Fase 1 — Core operativo** | 3 semanas | Gestión de eventos · Registro de entradas · Generación y envío de QR |
| **Fase 2 — Check-in** | 2 semanas | App Flutter staff · Escaneo QR nativo · Función `validate_qr()` · Resultado visual (color + ícono) · Cobro en puerta |
| **Fase 3 — Tiempo real** | 2 semanas | Dashboard React con Supabase Realtime · Feed de ingresos en vivo · Log de staff (`scan_logs`) |

---

## Setup

### Requisitos
- Flutter 3.x
- Node.js 18+ (solo para tooling de React, no como backend)
- Cuenta en Supabase

### Base de datos
```bash
# En el SQL Editor de Supabase:
# Pegar el contenido de supabase/schema.sql y ejecutar
```

### App Flutter (móvil y Flutter Web)
```bash
cd app
flutter pub get
flutter run
# Dashboard / web de Flutter:
flutter run -d chrome
```

### Sitio web (HTML / CSS / JS)
```bash
cd website
# Abrir index.html o servir la carpeta con un servidor estático
```

---

## Modelo de negocio

| Plan | Precio / mes | Eventos | Incluye |
|---|---|---|---|
| Starter | Bs. 150 | Hasta 4 | 1 admin · 2 staff · 200 QR/mes |
| Pro | Bs. 350 | Ilimitados | 3 admins · staff ilimitado · QR ilimitados · reportes |
| Local Premium | Bs. 600 | Ilimitados | Todo Pro + soporte prioritario + plano de sala (post-MVP) |

Cuando un organizador use CHECK y CLANDEST para el mismo evento, solo aplica la tarifa de CHECK.

---

## Integración futura con CLANDEST

> **Esta sección describe la visión a largo plazo.** La integración no es parte del MVP de CHECK ni del MVP de CLANDEST. Ambos productos deben alcanzar validación independiente primero.

**CLANDEST** es una app separada para descubrir eventos locales y underground en La Paz. Su foco es el descubrimiento: publicar eventos y conectar asistentes con lo que pasa en la ciudad. CHECK y CLANDEST son productos distintos con audiencias distintas en esta etapa.

### Por qué son separados hoy

- CLANDEST está orientado al **asistente**: descubrir, explorar y confirmar asistencia
- CHECK está orientado al **operador**: gestionar, controlar y ejecutar el evento en puerta
- Mantenerlos separados permite iterar cada producto de forma independiente y más rápida
- Bases de datos y autenticación completamente independientes en el MVP
- No todo evento de CLANDEST será gestionado por CHECK — esa distinción es parte del modelo de negocio (campos `check_event_id` / `gestionado_por_check` como vínculo liviano, no dependencia estructural)

### Qué se gana con la integración (visión)

| Funcionalidad | Descripción |
|---|---|
| Sincronización de eventos | Eventos creados en CHECK aparecen en CLANDEST para descubrimiento público |
| Confirmación de asistencia | Confirmar en CLANDEST agrega al asistente a la lista de invitados en CHECK |
| QR unificado | El QR generado por CLANDEST al confirmar es válido en el escáner de CHECK |
| Compra de entradas | El usuario compra desde CLANDEST y el QR se valida en puerta con CHECK |
| Métricas compartidas | El organizador ve descubrimiento (CLANDEST) y asistencia real (CHECK) en un solo lugar |
| Perfil unificado | Historial de eventos y asistencias en un solo perfil cross-producto |

---

*CHECK — La Paz, Bolivia · 2026*
