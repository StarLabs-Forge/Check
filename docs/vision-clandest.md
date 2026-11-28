# Integración futura con CLANDEST (visión, no implementada)

> Sección trasladada desde el README anterior sin cambios de contenido.


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

