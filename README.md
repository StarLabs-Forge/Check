# CHECK

### CHECK — Plataforma de Operaciones para Venues y Eventos en Tiempo Real

> Sistema de gestión para locales y organizadores de eventos — La Paz, Bolivia

![Estado](https://img.shields.io/badge/estado-MVP%20%2F%20Concepto-E63950)
![Plataforma](https://img.shields.io/badge/plataforma-Web%20%2B%20Mobile-1A1A2E)
![Flutter](https://img.shields.io/badge/mobile-Flutter-02569B)
![React](https://img.shields.io/badge/web-React-61DAFB)
![Supabase](https://img.shields.io/badge/backend-Supabase-3ECF8E)

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
  landing/                  # Sitio público (HTML/CSS/JS estático)
    index.html
    styles.css
    script.js
  supabase/                 # Backend real: schema, funciones, Edge Functions
    schema.sql               # Schema completo con RLS, funciones y triggers
    functions/                # Edge Functions (lógica de negocio)
    migrations/
  mobile/                   # App Flutter — staff (check-in)
    lib/
      screens/               # check_in, scan_result
      services/               # api_service, qr_scanner
  web/                       # Dashboard React — admin
    src/
      pages/                  # events, dashboard
      components/
  docs/                      # Especificación de producto, wireframes
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

### Edge Functions
```bash
cd supabase
supabase functions deploy
```

### App móvil (Staff)
```bash
cd mobile
flutter pub get
flutter run
```

### Dashboard web (Admin)
```bash
cd web
npm install
npm run dev
```

### Landing
```bash
# Sitio estático — abrir landing/index.html o servir con cualquier static host
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
