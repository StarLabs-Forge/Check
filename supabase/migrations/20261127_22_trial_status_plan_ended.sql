-- 22 · Un local cuyo plan terminó se informa como 'plan_ended', no como prueba vencida.
create or replace function public.trial_status() returns jsonb
language sql stable security definer set search_path = '' as $$
  select case
    when v.id is null then null
    when s.id is not null then jsonb_build_object('state', 'subscribed', 'plan', s.plan,
      'days_left', 0, 'ends_at', null, 'gate', g.commercial_gate)
    when coalesce(t.ends_at <= now(), true)
         and exists (select 1 from public.venue_subscriptions x where x.venue_id = v.id) then
      jsonb_build_object('state', 'plan_ended', 'days_left', 0, 'ends_at', null, 'gate', g.commercial_gate)
    when t.venue_id is not null then jsonb_build_object(
      'started_at', t.started_at, 'ends_at', t.ends_at, 'gate', g.commercial_gate,
      'state', case when now() >= t.ends_at then 'expired'
                    when t.ends_at - now() <= interval '3 days' then 'expiring' else 'active' end,
      'days_left', greatest(0, ceil(extract(epoch from (t.ends_at - now())) / 86400)::int))
    else null end
  from (select 1) d
  left join public.venues v on v.owner_id = auth.uid() and private.mfa_ok()
  left join public.venue_trials t on t.venue_id = v.id
  left join public.venue_subscriptions s on s.venue_id = v.id and s.ended_at is null
  left join public.platform_settings g on g.id
$$;
