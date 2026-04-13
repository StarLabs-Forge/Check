# CHECK

> Sistema de gestión para locales y organizadores de eventos — La Paz, Bolivia

![Estado](https://img.shields.io/badge/estado-MVP%20%2F%20Concepto-E63950)
![Plataforma](https://img.shields.io/badge/plataforma-Web%20%2B%20Mobile-1A1A2E)
![Flutter](https://img.shields.io/badge/mobile-Flutter-02569B)
![Node.js](https://img.shields.io/badge/backend-Node.js-339933)
![Supabase](https://img.shields.io/badge/database-Supabase-3ECF8E)

---

## ¿Qué es CHECK?

CHECK digitaliza y centraliza el control de acceso, la gestión de reservas de mesas y el manejo de entradas para locales nocturnos, bares, clubs y organizadores de eventos independientes.

El **QR es el eje central**: cada reserva de mesa y cada entrada genera un código único que el cliente recibe y presenta en puerta. El staff escanea el QR y obtiene al instante el estado completo — pagado, pendiente de cobro, o inválido.

> **CHECK opera como producto independiente.** Tiene su propia base de datos, backend y autenticación. En una versión futura se integrará con [CLANDEST](#integración-futura-con-clandest) para ofrecer un ecosistema completo. Ver sección al final.

---

## El problema que resuelve

- Control de acceso manual y propenso a errores (listas en papel, conteo a mano)
- Sin visibilidad en tiempo real de cuántos ingresaron vs. confirmados
- Reservas de mesa sin registro formal ni comprobante para el cliente
- Dificultad para delegar el control de puerta al staff sin perder visibilidad
- Sin historial de eventos para análisis posterior

---

## Stack tecnológico

| Capa | Tecnología | Uso |
|---|---|---|
| App Móvil (Staff) | Flutter (iOS + Android) | Check-in en puerta. Escaneo de QR nativo. Baja conectividad. |
| Web Dashboard (Admin) | Flutter Web | Panel de administración completo. |
| Backend / API | Node.js + Express | API REST. Validación de QR, reservas, tickets, generación de tokens. |
| Base de Datos | Supabase (PostgreSQL) | Tablas, RLS por rol, funciones y triggers. |
| Autenticación | Supabase Auth + JWT | Roles: Admin y Staff. Staff solo ve eventos asignados. |
| Tiempo Real | Supabase Realtime | Dashboard actualizado en vivo durante el evento. |
| Generación de QR | qrcode (Node.js) | Token único de 32 bytes firmado con pgcrypto. |
| Almacenamiento | Supabase Storage | Imágenes de QR para descarga y envío al cliente. |

---

## Estructura del proyecto

```
check/
  backend/                  # API Node.js + Express
    src/
      routes/               # events, reservations, tickets, qr, staff
      middleware/           # auth (JWT), roles, validación
      services/             # lógica de negocio
      utils/                # generador de QR, helpers
    supabase/
      schema.sql            # Schema completo con RLS, funciones y triggers
      migrations/
  mobile/                   # App Flutter — staff (check-in)
    lib/
      screens/              # check_in, scan_result
      services/             # api_service, qr_scanner
  web/                      # Dashboard Flutter Web — admin
    lib/
      screens/              # events, tables, reservations, dashboard
      widgets/
  docs/                     # Especificación de producto, wireframes
```

---

## Usuarios del sistema

### Admin (Dueño del local / Organizador)
Acceso completo. Crea eventos, configura mesas, gestiona reservas y lista de invitados, genera QR, ve el dashboard en tiempo real y administra al staff.

### Staff / Portero
Acceso restringido a los eventos asignados. Escanea QR, ve el resultado al instante, confirma cobros en puerta y busca invitados por nombre como respaldo.

---

## Flujo principal

```
Admin crea evento
  → configura mesas y zonas
    → registra reserva (nombre del grupo, mesa, pago)
      → sistema genera QR único firmado
        → admin envía QR al cliente (WhatsApp, etc.)
          → cliente presenta QR en puerta
            → staff escanea con app móvil
              → sistema responde con estado:
                  VERDE  — pagado, ingresa directo
                  AMARILLO — cobrar en puerta, confirmar
                  ROJO   — inválido / ya usado / cancelado
                    → log registrado con timestamp y staff_id
                      → dashboard del admin se actualiza en vivo
```

---

## Estados de QR en puerta

| Estado | Color | Acción del staff |
|---|---|---|
| Reserva pagada | 🟢 VERDE | Ingresa directo. Mesa confirmada. |
| Reserva pendiente de pago | 🟡 AMARILLO | Cobra en puerta. Confirma en el sistema. |
| Entrada pagada | 🟢 VERDE | Ingresa directo. |
| QR ya utilizado | 🔴 ROJO | Escaneado anteriormente. No permite reingreso. |
| QR inválido / no encontrado | 🔴 ROJO | No corresponde a ninguna reserva del evento. |
| Sin QR (búsqueda manual) | ⚫ GRIS | Staff busca por nombre en la lista. |

---

## Módulos

- **Gestión de Eventos** — crear, editar, duplicar. Estados: Borrador → Activo → En curso → Finalizado
- **Gestión de Mesas** — zonas (VIP, General, Terraza, etc.), estado en tiempo real, plano de sala (Fase 3)
- **Reservas y Tickets** — registro, generación de QR, envío al cliente, importación CSV (Fase 3)
- **Check-in (App Staff)** — escaneo QR nativo, resultado visual, cobro en puerta, búsqueda manual
- **Dashboard** — contadores en vivo, estado de mesas, feed de ingresos, alertas de capacidad
- **Gestión de Staff** — cuentas, asignación a eventos, log de actividad

---

## API Endpoints

### Autenticación
```
POST   /auth/login                  Login admin o staff
POST   /auth/staff                  Crear cuenta de staff (solo admin)
```

### Eventos
```
GET    /events                      Listar eventos del admin
POST   /events                      Crear evento
GET    /events/:id                  Detalle del evento
PATCH  /events/:id                  Actualizar evento
DELETE /events/:id                  Eliminar evento
GET    /events/:id/summary          Resumen de asistencia en tiempo real
```

### Mesas
```
GET    /events/:id/tables           Mesas con estado actual
POST   /events/:id/tables           Crear mesa
PATCH  /tables/:id                  Actualizar mesa
```

### Reservas
```
GET    /events/:id/reservations     Listar reservas
POST   /events/:id/reservations     Crear reserva + generar QR
PATCH  /reservations/:id            Actualizar reserva
GET    /reservations/:id/qr         Descargar imagen QR
```

### Tickets
```
GET    /events/:id/tickets          Listar tickets / lista de invitados
POST   /events/:id/tickets          Crear ticket + generar QR
PATCH  /tickets/:id                 Actualizar ticket
```

### Check-in (Staff)
```
POST   /checkin/scan                Validar QR escaneado → retorna estado y datos
POST   /checkin/confirm             Confirmar ingreso o cobro en puerta
GET    /checkin/search?name=        Búsqueda manual por nombre
```

---

## Base de datos

El schema completo está en `supabase/schema.sql`. Incluye tablas, enums, RLS, funciones y triggers listos para ejecutar en Supabase.

### Tablas principales

| Tabla | Descripción |
|---|---|
| `profiles` | Extiende auth.users. Rol (admin / staff), nombre, teléfono. |
| `venues` | Locales físicos. Un admin puede tener múltiples venues. |
| `events` | Eventos del admin. Tipo de acceso, capacidad, estado. |
| `event_staff` | Asignación de staff a eventos específicos. |
| `table_zones` | Zonas de mesas por evento (VIP, General, Terraza, etc.). |
| `tables` | Mesas físicas. Estado sincronizado automáticamente con reservas. |
| `reservations` | Reservas de mesa. QR único, estado de pago y check-in. |
| `tickets` | Entradas individuales. Mismo esquema de QR y estados. |
| `scan_logs` | Log inmutable de cada escaneo: staff, resultado, timestamp. |

### Funciones clave

- `generate_qr_token()` — token único de 32 bytes con pgcrypto
- `validate_qr(token, event_id)` — valida cualquier QR y retorna estado completo
- `sync_table_status()` — sincroniza estado de mesa con su reserva activa (trigger)

---

## Fases de desarrollo

| Fase | Duración | Entregables |
|---|---|---|
| **Fase 0** | 2 semanas | Schema Supabase · Auth con roles · API base · Generación de QR |
| **Fase 1** | 3 semanas | Gestión de eventos y mesas · Reservas · Generación de QR · Dashboard básico |
| **Fase 2** | 2 semanas | App Flutter staff · Escaneo QR · Resultado visual · Cobro en puerta |
| **Fase 3** | 4 semanas | Plano de sala · Importación CSV · Logs de staff · Alertas · Reportes |

---

## Setup

### Requisitos
- Node.js 18+
- Flutter 3.x
- Cuenta en Supabase

### Backend
```bash
cd backend
npm install
cp .env.example .env
# Completar SUPABASE_URL y SUPABASE_SERVICE_KEY
npm run dev
```

### Base de datos
```bash
# En el SQL Editor de Supabase:
# Pegar el contenido de supabase/schema.sql y ejecutar
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
flutter pub get
flutter run -d chrome
```

---

## Modelo de negocio

| Plan | Precio / mes | Eventos | Incluye |
|---|---|---|---|
| Starter | Bs. 150 | Hasta 4 | 1 admin · 2 staff · 200 QR/mes |
| Pro | Bs. 350 | Ilimitados | 3 admins · staff ilimitado · QR ilimitados · reportes |
| Local Premium | Bs. 600 | Ilimitados | Todo Pro + soporte prioritario + plano de sala |

---

## Integración futura con CLANDEST

> **Esta sección describe la visión a largo plazo.** La integración no es parte del MVP de CHECK ni del MVP de CLANDEST. Ambos productos deben alcanzar validación independiente primero.

**CLANDEST** es una app móvil separada para descubrir eventos locales y underground en La Paz. Su foco es el descubrimiento: publicar eventos y conectar asistentes con lo que pasa en la ciudad. CHECK y CLANDEST son productos distintos con audiencias distintas en esta etapa.

### Por qué son separados hoy

- CLANDEST está orientado al **asistente**: descubrir, explorar y confirmar asistencia
- CHECK está orientado al **operador**: gestionar, controlar y ejecutar el evento en puerta
- Mantenerlos separados permite iterar cada producto de forma independiente y más rápida
- Bases de datos, backends y autenticación completamente independientes en el MVP

### Qué se gana con la integración (visión)

| Funcionalidad | Descripción |
|---|---|
| Sincronización de eventos | Eventos creados en CHECK aparecen en CLANDEST para descubrimiento público |
| Confirmación de asistencia | Confirmar en CLANDEST agrega al asistente a la lista de invitados en CHECK |
| QR unificado | El QR generado por CLANDEST al confirmar es válido en el escáner de CHECK |
| Compra de entradas | El usuario compra desde CLANDEST y el QR se valida en puerta con CHECK |
| Reserva de mesa desde app | El asistente reserva y paga desde CLANDEST; CHECK gestiona la mesa |
| Métricas compartidas | El organizador ve descubrimiento (CLANDEST) y asistencia real (CHECK) en un solo lugar |
| Perfil unificado | Historial de eventos, reservas y asistencias en un solo perfil cross-producto |

---

*CHECK — La Paz, Bolivia · 2026*
