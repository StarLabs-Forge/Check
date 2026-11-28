# Configuración de Supabase Auth (panel)

Estos ajustes **no se pueden aplicar con migraciones**: se hacen en el panel de cada proyecto.
Aplícalos primero en `CHECK-DEV` y, tras validarlos, en producción.

## 1. Código OTP en el registro

1. Authentication → **Email Templates → Confirm signup**.
2. Sustituye el enlace (`{{ .ConfirmationURL }}`) por el código:

```html
<h2>Confirma tu correo en CHECK</h2>
<p>Escribe este código en la aplicación:</p>
<p style="font-size:28px;letter-spacing:6px"><strong>{{ .Token }}</strong></p>
<p>Si no creaste una cuenta, ignora este mensaje.</p>
```

3. **No cambies** las plantillas de recuperación de contraseña, cambio de correo ni invitación.
4. Authentication → Providers → Email: **Confirm email** activado. Anota la longitud del código
   (*Email OTP Length*, la app acepta 6–10) y su vigencia (*Email OTP Expiration*).

> Orden en producción: publica primero la app con la pantalla de código y después cambia la
> plantilla. La pantalla conserva «Ya confirmé con el enlace» para la transición.

## 2. Envío de correo (SMTP) — necesario para usuarios reales

Según la documentación de Supabase, el servicio de correo incluido **solo entrega a direcciones
del equipo del proyecto**, con un límite muy bajo por hora, y no es para producción. Para pruebas
en `CHECK-DEV` usa tu propio correo de miembro del equipo.

Para usuarios reales hay que configurar **SMTP propio** (Authentication → SMTP Settings). Opciones
con nivel gratuito a evaluar (verifica sus condiciones vigentes; ninguna se contrató): Resend,
Brevo, Amazon SES, SendGrid. Requieren un dominio verificado. El mismo proveedor puede enviar los
avisos de vencimiento de la prueba (tabla `trial_notifications`).

## 3. Contraseñas

Authentication → Providers → Email → **Minimum password length: 8**. No exijas clases de
caracteres (se permiten frases). *Leaked password protection* requiere plan Pro: no se contrató.

## 4. MFA (TOTP)

Authentication → **Multi-Factor**: TOTP habilitado (registro y verificación). Después de validar
el OTP y publicar la app, activa la exigencia en la base:

```sql
update public.platform_settings set mfa_required = true where id;
-- Revertir: update public.platform_settings set mfa_required = false where id;
```

## 5. Google OAuth

1. Google Cloud Console → *APIs & Services → Credentials → Create credentials → OAuth client ID*,
   tipo **Web application**. Configura la pantalla de consentimiento (en pruebas, añade los
   correos como *Test users*).
2. **Authorized redirect URI** (una por proyecto):
   - Desarrollo: `https://xcvmdtaxymuvudppmqjs.supabase.co/auth/v1/callback`
   - Producción: `https://lvejfwatzdqpzftjraut.supabase.co/auth/v1/callback`
3. **Authorized JavaScript origins:** `http://localhost:3000` (desarrollo) y
   `https://check-demo-three.vercel.app` (app real actual).
4. Supabase → Authentication → Providers → **Google**: pega el *Client ID* y el *Client Secret*
   (el secreto solo va aquí, nunca en el repositorio).
5. Supabase → Authentication → URL Configuration: *Site URL* con la URL de la app y en
   *Redirect URLs* los orígenes anteriores y `io.supabase.check://login-callback/`.

### Validación manual (requiere a una persona)

Con `flutter run -d chrome --web-port 3000 --dart-define-from-file=env/dev.json`:

| Caso | Acción | Resultado esperado |
|---|---|---|
| Usuario nuevo | «Registrarme con Google» | Pide completar datos → panel del local |
| Perfil completo | Cerrar sesión y «Continuar con Google» | Entra directo al panel, sin selector |
| Perfil incompleto | Cerrar la pestaña en «Completar perfil» y volver a entrar | Vuelve a pedir los datos |
| Cancelación | Cerrar o rechazar en Google | Mensaje de error, sin sesión |
| Persistencia | Recargar la página | La sesión se mantiene |
| Con MFA activo | Entrar como administrador | Pide el autenticador antes del panel |
