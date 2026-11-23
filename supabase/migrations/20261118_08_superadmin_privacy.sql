-- 08 · Superadmin: solo agregados por RPC; privacidad por local.

create table public.platform_log (
  id               bigint generated always as identity primary key,
  actor_id         uuid not null references public.profiles(id),
  action           text not null check (action in ('venue_suspended','venue_activated','plan_changed')),
  target_owner_id  uuid not null references public.profiles(id),
  detail           text check (char_length(detail) <= 200),
  created_at       timestamptz not null default now()
);
create index platform_log_target_idx on public.platform_log (target_owner_id, created_at desc);
create trigger platform_log_immutable before update or delete on public.platform_log
  for each row execute function private.block_audit_mutation();
alter table public.platform_log enable row level security;
create policy platform_log_select on public.platform_log for select to authenticated
  using ((select private.is_super_admin()));
revoke all on public.platform_log from anon, authenticated;
grant select on public.platform_log to authenticated;

create function public.superadmin_venues_overview() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_super_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
      'owner_id', p.id,
      'venue_name', coalesce(v.name, 'Sin nombre'),
      'zone', v.zone, 'plan', p.plan, 'status', p.status, 'created_at', p.created_at,
      'events', (select count(*) from public.events e where e.owner_id = p.id),
      'events_active', (select count(*) from public.events e
                        where e.owner_id = p.id and e.status in ('active','live')),
      'tickets_issued', (select count(*) from public.tickets tk join public.events e on e.id = tk.event_id
                         where e.owner_id = p.id and tk.status <> 'cancelled'),
      'orders', (select coalesce(jsonb_object_agg(s.status, s.n), '{}'::jsonb)
                 from (select o.status::text as status, count(*) as n
                       from public.orders o join public.events e on e.id = o.event_id
                       where e.owner_id = p.id group by o.status) s),
      'verifiers', (select count(*) from public.payment_verifiers pv
                    where pv.owner_id = p.id and pv.revoked_at is null),
      'last_activity', (select max(a.created_at) from public.audit_log a where a.owner_id = p.id)
    ) order by v.name), '[]'::jsonb)
    from public.profiles p left join public.venues v on v.owner_id = p.id
    where p.role = 'admin');
end $$;

create function public.superadmin_audit_summary() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_super_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  return (
    select coalesce(jsonb_agg(r order by r ->> 'venue_name'), '[]'::jsonb) from (
      select jsonb_build_object(
        'owner_id', p.id,
        'venue_name', coalesce(v.name, 'Sin nombre'),
        'approved', count(a.id) filter (where a.action = 'order_approved'),
        'rejected', count(a.id) filter (where a.action = 'order_rejected'),
        'conflicts', count(a.id) filter (where a.action = 'payment_conflict'),
        'by_verifiers', count(a.id) filter (where a.actor_permission = 'verifier'
                                              and a.action in ('order_approved','order_rejected')),
        'permission_changes', count(a.id) filter (where a.action in ('verifier_granted','verifier_revoked')),
        'last_activity', max(a.created_at)
      ) as r
      from public.profiles p
      left join public.venues v on v.owner_id = p.id
      left join public.audit_log a on a.owner_id = p.id and a.created_at > now() - interval '30 days'
      where p.role = 'admin'
      group by p.id, v.name
    ) t);
end $$;

create function public.superadmin_set_venue_status(p_owner_id uuid, p_status public.account_status)
returns void language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_old public.account_status;
begin
  if not private.is_super_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  select status into v_old from public.profiles where id = p_owner_id and role = 'admin' for update;
  if not found then raise exception 'venue_not_found' using errcode = 'P0001'; end if;
  if v_old = p_status then return; end if;
  update public.profiles set status = p_status where id = p_owner_id;
  insert into public.platform_log (actor_id, action, target_owner_id)
  values (v_uid, case when p_status = 'suspended' then 'venue_suspended' else 'venue_activated' end, p_owner_id);
end $$;

create function public.superadmin_set_plan(p_owner_id uuid, p_plan public.plan_type)
returns void language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_old public.plan_type;
begin
  if not private.is_super_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  select plan into v_old from public.profiles where id = p_owner_id and role = 'admin' for update;
  if not found then raise exception 'venue_not_found' using errcode = 'P0001'; end if;
  if v_old = p_plan then return; end if;
  update public.profiles set plan = p_plan where id = p_owner_id;
  insert into public.platform_log (actor_id, action, target_owner_id, detail)
  values (v_uid, 'plan_changed', p_owner_id, v_old::text || ' -> ' || p_plan::text);
end $$;

revoke all on function public.superadmin_venues_overview(), public.superadmin_audit_summary(),
  public.superadmin_set_venue_status(uuid, public.account_status),
  public.superadmin_set_plan(uuid, public.plan_type) from public, anon, authenticated;
grant execute on function public.superadmin_venues_overview(), public.superadmin_audit_summary(),
  public.superadmin_set_venue_status(uuid, public.account_status),
  public.superadmin_set_plan(uuid, public.plan_type) to authenticated;

-- Privacidad por local: el superadmin ya no lee boletos (datos de compradores),
-- bitácora de escaneo ni nombres del staff de cada local; solo agregados por RPC.
drop policy tickets_select on public.tickets;
create policy tickets_select on public.tickets for select to authenticated
  using (private.owns_event(event_id));

drop policy scan_logs_select on public.scan_logs;
create policy scan_logs_select on public.scan_logs for select to authenticated
  using (private.owns_event(event_id));

drop policy event_staff_select on public.event_staff;
create policy event_staff_select on public.event_staff for select to authenticated
  using (private.owns_event(event_id) or staff_id = (select auth.uid()));

drop policy profiles_select_super on public.profiles;
create policy profiles_select_super on public.profiles for select to authenticated
  using ((select private.is_super_admin()) and role in ('admin','super_admin'));
