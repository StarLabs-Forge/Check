# Cuenta de super administrador

La cuenta **no se crea desde la app ni desde código**. Se hace a mano:

1. Supabase → Authentication → Users → **Add user** (marca **Auto Confirm User**). Usa un correo y
   una contraseña de al menos 8 caracteres.
2. En el SQL Editor, reemplaza `<correo>` y ejecuta:

```sql
update public.profiles set role = 'super_admin', status = 'active'
where id = (select id from auth.users where email = '<correo>');
```

3. Inicia sesión en la app con ese correo: te lleva a `/superadmin` (si el MFA está activo,
   primero configurarás el autenticador).

## Notas

- Con el **registro cerrado** (Plataforma → Ajustes), las cuentas creadas por su cuenta nacen con
  `status = 'suspended'`. El `status = 'active'` del SQL anterior es lo que habilita la cuenta.
- Los locales que da de alta el super admin (`create-venue`) y el staff que crea cada admin
  (`create-staff`) se crean con `app_metadata.provisioned = true`.
- El super admin **no puede leer** empleados ni compradores de los locales (privacidad).

## Recuperar el MFA de un administrador de local

Desde la app: **Locales → el local → Restablecer MFA**.

1. Verifica la identidad de la persona por un canal independiente (videollamada, documento).
2. Escribe cómo la verificaste (mínimo 10 caracteres). Tu propia sesión debe tener MFA.
3. La Edge Function `mfa-reset` registra la operación (`mfa_resets`, `platform_log`), elimina sus
   factores y —con la migración 21 aplicada— cierra sus sesiones. Los tokens antiguos dejan de
   ejercer el rol desde ese instante.
4. En su siguiente ingreso deberá configurar un autenticador nuevo antes de ver su panel.

## Recuperar el MFA del super administrador (solo el propietario del proyecto Supabase)

No existe ningún mecanismo público. No hay códigos de recuperación ni autenticadores de reserva
en V1.

1. **Autorización:** solo la persona propietaria del proyecto en Supabase, tras verificar la
   identidad de quien lo pide. Deja constancia escrita (fecha, quién, motivo, cómo se verificó).
2. **Restablecer el factor:** Supabase → Authentication → Users → la cuenta → eliminar sus
   factores MFA.
3. **Revocar sesiones y registrar** en el SQL Editor (reemplaza `<correo>` y el motivo):

```sql
with u as (select id from auth.users where email = '<correo>')
insert into public.mfa_resets (target_id, authorized_by, reason)
select id, id, 'Restablecimiento manual por el propietario: <motivo y verificación>' from u;

delete from auth.sessions where user_id = (select id from auth.users where email = '<correo>');
```

4. **Reconfigurar:** la persona inicia sesión y registra un autenticador nuevo.
5. Verifica que entra al panel y anota el cierre de la incidencia.

Recomendación: protege también la cuenta de Supabase del propietario con MFA; es la raíz de
confianza de este procedimiento.
