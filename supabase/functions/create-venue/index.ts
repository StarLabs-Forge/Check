// Alta de un local (usuario administrador + venue). Solo super_admin.
// La service role vive únicamente aquí (variable de entorno del Edge Runtime).
import { createClient } from 'jsr:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const PLANS = ['starter', 'pro', 'premium'];

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'Método no permitido' }, 405);

  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

  const token = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
  const { data: caller } = await admin.auth.getUser(token);
  if (!caller.user) return json({ error: 'No autenticado' }, 401);
  const actor = caller.user.id;
  const { data: prof } = await admin.from('profiles').select('role,status').eq('id', actor).maybeSingle();
  if (!prof || prof.status !== 'active' || prof.role !== 'super_admin') return json({ error: 'Sin permiso' }, 403);

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json({ error: 'JSON inválido' }, 400); }

  const venueName = String(body.venue_name ?? '').trim().slice(0, 120);
  const zone = String(body.zone ?? '').trim().slice(0, 80);
  const fullName = String(body.full_name ?? '').trim().slice(0, 120);
  const email = String(body.email ?? '').trim().toLowerCase();
  const password = body.password;
  const plan = String(body.plan ?? 'starter');
  if (!venueName || !fullName || !EMAIL.test(email) || !PLANS.includes(plan) ||
      typeof password !== 'string' || password.length < 8 || password.length > 72) {
    return json({ error: 'Datos incompletos o inválidos' }, 400);
  }

  const { data, error } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { full_name: fullName, venue_name: venueName },
    app_metadata: { provisioned: true },
  });
  if (error || !data.user) return json({ error: error?.message ?? 'No se pudo crear' }, 400);
  const id = data.user.id;

  const up = await admin.from('profiles')
    .update({ role: 'admin', plan, status: 'active', full_name: fullName }).eq('id', id);
  const ven = up.error ? up : await admin.from('venues').insert({ owner_id: id, name: venueName, zone: zone || null });
  const log = ven.error ? ven : await admin.from('platform_log')
    .insert({ actor_id: actor, action: 'venue_created', target_owner_id: id, detail: venueName.slice(0, 200) });
  if (log.error) {
    await admin.auth.admin.deleteUser(id);
    return json({ error: 'No se pudo crear el local' }, 500);
  }
  return json({ id });
});
