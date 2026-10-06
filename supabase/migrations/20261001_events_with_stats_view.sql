-- Vista de eventos con contadores de tickets, usada por el panel Admin
-- (dashboard, lista y detalle de eventos, métricas de tickets).
--
-- security_invoker = true  → se evalúan las políticas RLS de `events` y
-- `tickets` con el usuario que consulta: cada admin ve solo lo suyo.
-- Ya aplicada en el proyecto Supabase "check" (lvejfwatzdqpzftjraut).
create or replace view public.events_with_stats
with (security_invoker = true) as
select e.*,
  count(t.id) filter (where t.status <> 'cancelled')                                   as tickets_total,
  count(t.id) filter (where t.status <> 'cancelled' and t.payment_status = 'paid')     as tickets_paid,
  count(t.id) filter (where t.status = 'issued' and t.payment_status = 'pending')      as tickets_pending_payment,
  count(t.id) filter (where t.status = 'used')                                         as checkins,
  count(t.id) filter (where t.status = 'cancelled')                                    as tickets_cancelled,
  count(t.id) filter (where t.status = 'used' and t.checked_in_at >= now() - interval '1 hour') as checkins_last_hour
from public.events e
left join public.tickets t on t.event_id = e.id
group by e.id;

revoke all on public.events_with_stats from anon, public;
grant select on public.events_with_stats to authenticated;
