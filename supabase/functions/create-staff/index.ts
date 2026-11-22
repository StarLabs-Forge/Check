import { createClient } from 'jsr:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

const PERMS = ['scanQr', 'verifyPayments', 'viewGuests', 'createTickets', 'viewEvents'];
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'Método no permitido' }, 405);

  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

  const token = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
  const { data: caller } = await admin.auth.getUser(token);
  if (!caller.user) return json({ error: 'No autenticado' }, 401);
  const owner = caller.user.id;
  const { data: prof } = await admin.from('profiles').select('role,status').eq('id', owner).maybeSingle();
  if (!prof || prof.status !== 'active' || prof.role !== 'admin') return json({ error: 'Sin permiso' }, 403);

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json({ error: 'JSON inválido' }, 400); }
  const action = String(body.action ?? 'create');

  const audit = (act: string) =>
    admin.from('audit_log').insert({ owner_id: owner, actor_id: owner, actor_permission: 'admin', action: act, result: 'ok' });

  const mine = async (id: unknown) => {
    if (typeof id !== 'string') return null;
    const { data } = await admin.from('staff_accounts').select('staff_id').eq('staff_id', id).eq('owner_id', owner).maybeSingle();
    return data;
  };
  const okPassword = (p: unknown) => typeof p === 'string' && p.length >= 8 && p.length <= 72;

  if (action === 'create') {
    const full_name = String(body.full_name ?? '').trim().slice(0, 120);
    const email = String(body.email ?? '').trim().toLowerCase();
    const password = body.password;
    const job = String(body.job ?? '').trim().slice(0, 80);
    const permissions = Array.isArray(body.permissions) ? (body.permissions as string[]).filter((p) => PERMS.includes(p)) : [];
    if (!full_name || !EMAIL.test(email) || !okPassword(password)) return json({ error: 'Datos incompletos o inválidos' }, 400);

    const { data, error } = await admin.auth.admin.createUser({
      email,
      password: password as string,
      email_confirm: true,
      user_metadata: { full_name, created_by: owner },
    });
    if (error || !data.user) return json({ error: error?.message ?? 'No se pudo crear' }, 400);
    const id = data.user.id;
    const up = await admin.from('profiles').update({ role: 'staff', full_name }).eq('id', id);
    const ins = up.error
      ? up
      : await admin.from('staff_accounts').insert({ staff_id: id, owner_id: owner, job, permissions, email, full_name });
    if (ins.error) {
      await admin.auth.admin.deleteUser(id);
      return json({ error: 'No se pudo crear la cuenta' }, 500);
    }
    await audit('staff_created');
    return json({ id });
  }

  if (!(await mine(body.staff_id))) return json({ error: 'Cuenta no encontrada' }, 404);
  const id = body.staff_id as string;

  if (action === 'reset_password') {
    if (!okPassword(body.password)) return json({ error: 'La contraseña debe tener entre 8 y 72 caracteres' }, 400);
    const { error } = await admin.auth.admin.updateUserById(id, { password: body.password as string });
    if (error) return json({ error: error.message }, 400);
    await audit('staff_password_reset');
    return json({ ok: true });
  }

  if (action === 'set_active') {
    const active = body.active === true;
    const { error } = await admin.from('staff_accounts').update({ active }).eq('staff_id', id);
    if (error) return json({ error: 'No se pudo actualizar' }, 500);
    await admin.auth.admin.updateUserById(id, { ban_duration: active ? 'none' : '876000h' });
    await audit(active ? 'staff_activated' : 'staff_deactivated');
    return json({ ok: true });
  }

  if (action === 'delete') {
    const { count } = await admin.from('event_staff').select('id', { count: 'exact', head: true }).eq('staff_id', id);
    if ((count ?? 0) > 0) return json({ error: 'La cuenta tiene historial en eventos; desactívala en su lugar.' }, 409);
    const { error } = await admin.auth.admin.deleteUser(id);
    if (error) return json({ error: error.message }, 400);
    await audit('staff_deleted');
    return json({ ok: true });
  }

  return json({ error: 'Acción desconocida' }, 400);
});
