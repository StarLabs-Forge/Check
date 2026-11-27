create table public.staff_accounts (
  staff_id    uuid primary key references public.profiles(id) on delete cascade,
  owner_id    uuid not null references public.profiles(id) on delete cascade,
  job         text not null default '' check (char_length(job) <= 80),
  permissions text[] not null default '{}',
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint staff_accounts_perms_chk check (
    permissions <@ array['scanQr','verifyPayments','viewGuests','createTickets','viewEvents']::text[])
);
create index staff_accounts_owner_idx on public.staff_accounts (owner_id);

create trigger staff_accounts_updated before update on public.staff_accounts
  for each row execute function private.set_updated_at();

alter table public.staff_accounts enable row level security;
create policy staff_accounts_select on public.staff_accounts for select to authenticated
  using (owner_id = (select auth.uid()) or staff_id = (select auth.uid()));
revoke all on public.staff_accounts from public, anon, authenticated;
grant select on public.staff_accounts to authenticated;

alter table public.audit_log drop constraint audit_log_action_check;
alter table public.audit_log add constraint audit_log_action_check check (action = any (array[
  'order_approved','order_rejected','payment_conflict','verifier_granted','verifier_revoked',
  'staff_created','staff_updated','staff_activated','staff_deactivated','staff_deleted',
  'staff_password_reset','staff_events_changed']));

create or replace function private.is_event_staff(p_event_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce(private.current_user_role() = 'staff', false)
     and exists (select 1 from public.event_staff es
                 join public.events e on e.id = es.event_id
                 where es.event_id = p_event_id
                   and es.staff_id = (select auth.uid())
                   and es.revoked_at is null
                   and e.status in ('active', 'live'))
     and not exists (select 1 from public.staff_accounts sa
                     where sa.staff_id = (select auth.uid()) and not sa.active)
$$;

create or replace function private.can_operate_door(p_event_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select (private.is_event_staff(p_event_id)
          and not exists (select 1 from public.staff_accounts sa
                          where sa.staff_id = (select auth.uid())
                            and not ('scanQr' = any (sa.permissions))))
      or (private.owns_event(p_event_id)
          and exists (select 1 from public.events e
                      where e.id = p_event_id and e.status in ('active', 'live')))
$$;

create or replace function private.can_verify_payments(p_event_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select private.owns_event(p_event_id)
      or (coalesce(private.current_user_role() = 'staff', false)
          and exists (select 1 from public.events e
                      join public.payment_verifiers pv on pv.owner_id = e.owner_id
                      where e.id = p_event_id
                        and pv.verifier_id = (select auth.uid())
                        and pv.revoked_at is null)
          and not exists (select 1 from public.staff_accounts sa
                          where sa.staff_id = (select auth.uid())
                            and (not sa.active or not ('verifyPayments' = any (sa.permissions)))))
$$;

create or replace function private.my_staff(p_staff_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or private.current_user_role() is distinct from 'admin' then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if not exists (select 1 from public.staff_accounts where staff_id = p_staff_id and owner_id = auth.uid()) then
    raise exception 'not_your_staff' using errcode = 'P0001';
  end if;
end $$;

create function public.staff_update(p_staff_id uuid, p_job text, p_permissions text[], p_active boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare v_old boolean;
begin
  perform private.my_staff(p_staff_id);
  select active into v_old from public.staff_accounts where staff_id = p_staff_id for update;
  update public.staff_accounts
     set job = left(coalesce(p_job, job), 80),
         permissions = coalesce(p_permissions, permissions),
         active = coalesce(p_active, active)
   where staff_id = p_staff_id;
  insert into public.audit_log (owner_id, actor_id, actor_permission, action, result)
  values (auth.uid(), auth.uid(), 'admin',
          case when p_active is not null and p_active <> v_old
               then case when p_active then 'staff_activated' else 'staff_deactivated' end
               else 'staff_updated' end, 'ok');
end $$;

create function public.staff_set_events(p_staff_id uuid, p_event_ids uuid[])
returns void language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_name text;
begin
  perform private.my_staff(p_staff_id);
  if exists (select 1 from unnest(coalesce(p_event_ids, '{}')) i
             where not exists (select 1 from public.events e where e.id = i and e.owner_id = v_uid)) then
    raise exception 'event_not_yours' using errcode = 'P0001';
  end if;
  select left(coalesce(nullif(full_name, ''), 'Staff'), 80) into v_name from public.profiles where id = p_staff_id;

  update public.event_staff es set revoked_at = now()
   where es.staff_id = p_staff_id and es.revoked_at is null
     and es.event_id in (select id from public.events where owner_id = v_uid)
     and not (es.event_id = any (coalesce(p_event_ids, '{}')));

  insert into public.event_staff (event_id, staff_id, display_name, code_hash, code_expires_at, redeemed_at, created_by)
  select i, p_staff_id, v_name, 'direct:' || gen_random_uuid()::text, now(), now(), v_uid
    from unnest(coalesce(p_event_ids, '{}')) i
   where not exists (select 1 from public.event_staff x
                     where x.event_id = i and x.staff_id = p_staff_id and x.revoked_at is null);

  insert into public.audit_log (owner_id, actor_id, actor_permission, action, result)
  values (v_uid, v_uid, 'admin', 'staff_events_changed', 'ok');
end $$;

create function public.staff_event_ids(p_staff_id uuid) returns uuid[]
language sql stable security definer set search_path = '' as $$
  select coalesce(array_agg(es.event_id), '{}')
    from public.event_staff es join public.events e on e.id = es.event_id
   where es.staff_id = p_staff_id and es.revoked_at is null and e.owner_id = auth.uid()
$$;

revoke all on function private.my_staff(uuid) from public, anon, authenticated;
revoke all on function public.staff_update(uuid, text, text[], boolean),
  public.staff_set_events(uuid, uuid[]), public.staff_event_ids(uuid) from public, anon, authenticated;
grant execute on function public.staff_update(uuid, text, text[], boolean),
  public.staff_set_events(uuid, uuid[]), public.staff_event_ids(uuid) to authenticated;
