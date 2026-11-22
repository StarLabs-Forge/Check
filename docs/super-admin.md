# Cuenta de super administrador

La cuenta **no se crea desde la app ni desde código**. Se hace a mano:

1. Supabase → Authentication → Users → **Add user** (marca **Auto Confirm User**). Usa el correo y la contraseña que quieras.
2. En el SQL Editor, reemplaza `<correo>` y ejecuta:

```sql
update public.profiles set role = 'super_admin', status = 'active'
where id = (select id from auth.users where email = '<correo>');
```

3. Inicia sesión en la app con ese correo: te lleva a `/superadmin`.

## Notas

- Con el **registro cerrado** (Plataforma → Ajustes), las cuentas creadas por su cuenta nacen con `status = 'suspended'`. El `status = 'active'` del SQL anterior es lo que habilita la cuenta, así que el paso 2 sirve igual.
- Los locales que da de alta el super admin (Edge Function `create-venue`) y el staff que crea cada admin (`create-staff`) se crean con `app_metadata.provisioned = true`, por eso no les afecta el registro cerrado.
- El super admin **no puede leer** empleados ni compradores de los locales (privacidad). Solo ve administradores, conteos y su propia bitácora (`platform_log`).
