# Plan de despliegue a producción (pendiente de autorización)

Nada de esto se ha ejecutado en producción (`lvejfwatzdqpzftjraut`). Cada paso lo autoriza la
persona propietaria.

## 0. Antes de empezar

- [ ] Completar en `CHECK-DEV` las validaciones manuales (OTP real, MFA real, Google).
- [ ] **Respaldo:** el plan gratuito no ofrece copias descargables automáticas. Exporta con
      `pg_dump` (cadena de conexión del panel) el esquema y los datos de `public` y `auth`, y
      guarda el archivo fuera del repositorio. Comprueba que se puede leer.
- [ ] Elegir una ventana sin eventos en curso.

## 1. Diferencias entre producción y el repositorio

Producción tiene aplicadas las migraciones hasta `superadmin_platform` (13). Pendientes, en orden:
`14 → 16 → 17 → 18 → 19 → 20 → 21 → 22 → 23`, y **15 al final** (ver abajo). Las migraciones 01–05,
10a y 10b ya están en producción: se añadieron al repositorio solo para poder reconstruir la base.

## 2. Compatibilidad entre app y base

| Combinación | Resultado |
|---|---|
| App nueva + base antigua | Cambiar el estado de un evento y gestionar categorías **fallan** con aviso (ya no hay vía sin auditoría) |
| App antigua + base 18 | Emitir entradas manuales **falla** con `ticket_type_required` (a propósito) |
| App antigua + base 15 | Cambiar estados falla (`permission denied`) |
| App antigua + base 14–17, 19–22 | Funciona |

Por eso: **migrar y publicar la app en la misma ventana**.

## 3. Orden

1. Aplicar 14, 16, 17, 18, 19, 20, 21, 22, 23 (interruptores `commercial_gate` y `mfa_required` quedan
   en `false`: no bloquean nada).
2. Desplegar Edge Functions `create-staff`, `create-venue`, `mfa-reset`.
3. Publicar la app (Vercel) y el sitio web desde el mismo commit.
4. Verificar (sección 5).
5. Aplicar **15** (revoca el `UPDATE` directo de `events.status`).
6. Configurar Auth (`docs/configuracion-auth.md`): contraseña mínima, SMTP, plantilla OTP,
   Google. Validar con un correo real.
7. **Locales existentes:** antes de activar el control comercial, asigna plan o avisa que activen
   su prueba. Revisa con:
   ```sql
   select v.name, private.commercial_state(v.owner_id) from public.venues v order by 1;
   ```
   Luego `update public.platform_settings set commercial_gate = true where id;`
8. Con OTP validado y super admin con autenticador configurado:
   `update public.platform_settings set mfa_required = true where id;`

## 4. Recuperación

| Problema | Reversión |
|---|---|
| Bloqueos comerciales inesperados | `update public.platform_settings set commercial_gate = false where id;` |
| Nadie puede entrar por MFA | `update public.platform_settings set mfa_required = false where id;` |
| La app publicada no puede cambiar estados tras 15 | `grant update (status) on public.events to authenticated;` |
| Fallo de la app | Promover el despliegue anterior en Vercel (con 18 aplicada no podrá emitir entradas manuales) |
| Fallo de una migración | Cada una es transaccional: si falla no deja cambios. Para deshacer una ya aplicada, corregir con una migración nueva; como último recurso, restaurar el respaldo |

Las migraciones no borran datos de negocio. La 21 borra filas de `auth.sessions` únicamente del
administrador cuyo MFA se restablece.

Operaciones a vigilar: la 18 impide **aumentar o crear** categorías si la suma supera el aforo
(los datos existentes no se modifican); revisar eventos que ya la superen:
```sql
select e.name, e.capacity, sum(t.capacity) from public.events e
join public.ticket_types t on t.event_id = e.id group by e.id having sum(t.capacity) > e.capacity;
```

## 5. Pruebas posteriores al despliegue (sin datos destructivos)

- [ ] Catálogo público carga y muestra categorías.
- [ ] Un administrador publica y devuelve a borrador un evento de prueba propio (queda en
      `event_status_log`).
- [ ] Emitir una entrada manual con categoría descuenta cupo.
- [ ] Registro con un correo real recibe el código y entra.
- [ ] Superadmin con MFA entra a su panel; asignar plan a un local de prueba.
- [ ] `get_advisors` (seguridad) sin hallazgos nuevos de nivel ERROR.
- No ejecutes en producción los archivos de `supabase/tests/`.

## 6. Eliminar CHECK-DEV

Solo cuando: el proyecto haya terminado, las migraciones estén validadas y desplegadas en
producción, y no quede información única en dev.

1. Confirmar el identificador: **`xcvmdtaxymuvudppmqjs`**, nombre `CHECK-DEV`, creado el
   27/11/2026. **No** es `lvejfwatzdqpzftjraut` (`check`, producción).
2. Verificar que no contiene datos reales (solo fixtures `Fixture Concurrencia *`).
3. Con la **confirmación expresa** de la persona propietaria: panel → Project Settings → General →
   Delete project (o pausarlo si se quiere conservar).
4. Borrar `app/env/dev.json` local.
