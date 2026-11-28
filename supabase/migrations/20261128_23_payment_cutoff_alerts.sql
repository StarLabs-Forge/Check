-- 23 · Corte de las 10:00 del día del evento (hora de Bolivia) para pagos informados.
-- Regla aprobada: SOLO AVISAR al administrador. No anula pedidos, no libera cupos
-- y no impide aprobar o rechazar después del corte.
create or replace function public.payment_cutoff_alerts() returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('event_id', x.id, 'event_name', x.name,
           'cutoff_at', x.cutoff_at, 'pending', x.pending) order by x.cutoff_at, x.name), '[]'::jsonb)
  from (
    select e.id, e.name, count(*)::int as pending,
           (date_trunc('day', e.starts_at at time zone 'America/La_Paz') + interval '10 hours')
             at time zone 'America/La_Paz' as cutoff_at
    from public.orders o join public.events e on e.id = o.event_id
    where o.status = 'verifying' and private.owns_event(e.id)
    group by e.id
  ) x
  where x.cutoff_at <= now()
$$;
revoke all on function public.payment_cutoff_alerts() from public, anon;
grant execute on function public.payment_cutoff_alerts() to authenticated;
