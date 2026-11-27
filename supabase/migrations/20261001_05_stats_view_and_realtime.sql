-- Contadores del dashboard. security_invoker => respeta el RLS de quien consulta.
create view public.event_stats with (security_invoker = true) as
select
  e.id as event_id,
  e.capacity,
  count(t.id) filter (where t.status <> 'cancelled')                              as tickets_total,
  count(t.id) filter (where t.status <> 'cancelled' and t.payment_status = 'paid') as tickets_paid,
  count(t.id) filter (where t.status = 'issued' and t.payment_status = 'pending')  as tickets_pending,
  count(t.id) filter (where t.status = 'used')                                     as checked_in
from public.events e
left join public.tickets t on t.event_id = e.id
group by e.id, e.capacity;

grant select on public.event_stats to authenticated;

-- Realtime (respeta RLS: cada usuario solo recibe lo que puede leer)
alter publication supabase_realtime add table public.tickets, public.scan_logs, public.events;
