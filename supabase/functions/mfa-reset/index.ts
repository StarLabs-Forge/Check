// Restablece el MFA de un administrador de local. Solo super_admin con aal2.
// La autorización, el motivo, la auditoría y la revocación de sesiones los hace la
// base (superadmin_authorize_mfa_reset) con el token de quien llama; esta función
// solo usa la service role para borrar los factores con la Admin API.
// El superadministrador NO se recupera por aquí (ver docs/super-admin.md).
import { createClient } from 'jsr:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'Método no permitido' }, 405);

  const authorization = req.headers.get('Authorization') ?? '';
  const url = Deno.env.get('SUPABASE_URL')!;
  const caller = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authorization } },
  });

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json({ error: 'JSON inválido' }, 400); }
  const userId = String(body.user_id ?? '');
  const reason = String(body.reason ?? '').trim();
  if (!UUID.test(userId) || reason.length < 10 || reason.length > 300) {
    return json({ error: 'Indica la cuenta y un motivo de al menos 10 caracteres' }, 400);
  }

  const { error: denied } = await caller.rpc('superadmin_authorize_mfa_reset', { p_user_id: userId, p_reason: reason });
  if (denied) {
    const forbidden = /forbidden|permission denied/.test(denied.message);
    return json({ error: forbidden ? 'Sin permiso (requiere superadministrador con MFA)' : denied.message },
      forbidden ? 403 : 400);
  }

  const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const { data, error } = await admin.auth.admin.mfa.listFactors({ userId });
  if (error) return json({ error: 'Restablecimiento autorizado, pero no se pudieron leer los factores. Reintenta.' }, 502);
  let removed = 0;
  for (const factor of data.factors) {
    const res = await admin.auth.admin.mfa.deleteFactor({ id: factor.id, userId });
    if (res.error) return json({ error: 'No se pudo eliminar un factor. Reintenta.' }, 502);
    removed++;
  }
  return json({ ok: true, factors_removed: removed });
});
