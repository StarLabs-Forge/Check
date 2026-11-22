// Crea una cuenta de staff (Auth + perfil). Solo la puede invocar un admin.
// La service role vive únicamente aquí (variable de entorno del Edge Runtime).
import { createClient } from 'jsr:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  const url = Deno.env.get('SUPABASE_URL')!;
  const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

  const token = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
  const { data: caller } = await admin.auth.getUser(token);
  if (!caller.user) return json({ error: 'No autenticado' }, 401);
  const { data: prof } = await admin.from('profiles').select('role,status').eq('id', caller.user.id).maybeSingle();
  if (!prof || prof.status !== 'active' || !['admin', 'super_admin'].includes(prof.role)) {
    return json({ error: 'Sin permiso' }, 403);
  }

  const { full_name, email, password, permissions } = await req.json();
  if (!full_name || !email || !password || String(password).length < 8) {
    return json({ error: 'Datos incompletos' }, 400);
  }
  const { data, error } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { full_name, role: 'staff', created_by: caller.user.id, permissions: permissions ?? [] },
  });
  if (error || !data.user) return json({ error: error?.message ?? 'No se pudo crear' }, 400);
  // El trigger handle_new_user crea el perfil; fijamos rol staff por si acaso.
  await admin.from('profiles').update({ role: 'staff', full_name }).eq('id', data.user.id);
  return json({ id: data.user.id });
});
