-- 19 · Prueba gratuita por local, planes activados por el superadministrador,
--      restricciones comerciales en el servidor y cola de avisos de vencimiento.
--
-- INTERRUPTOR DE DESPLIEGUE: platform_settings.commercial_gate (por defecto false).
-- Con false no se bloquea nada (los locales existentes siguen operando). Activarlo
-- SOLO después de asignar plan o prueba a los locales existentes.

alter table public.platform_settings add column commercial_gate boolean not null default false;

-- ── Prueba asociada al local (no a la cuenta del administrador) ──────────────
alter table public.venue_trials add column venue_id uuid references public.venues(id);
alter table public.venue_trials disable trigger venue_trials_immutable;
update public.venue_trials t set venue_id = v.id from public.venues v where v.owner_id = t.owner_id;
alter table public.venue_trials enable trigger venue_trials_immutable;
alter table public.venue_trials drop constraint venue_trials_pkey;
alter table public.venue_trials alter column venue_id set not null;
alter table public.venue_trials add primary key (venue_id);
-- owner_id deja de ser la clave: solo conserva quién activó la prueba.
alter table public.venue_trials alter column owner_id drop not null;
comment on column public.venue_trials.owner_id is 'Cuenta que activó la prueba (histórico). La prueba pertenece al local.';
alter policy venue_trials_select on public.venue_trials
  using (exists (select 1 from public.venues v where v.id = venue_id and v.owner_id = (select auth.uid())));

-- ── Planes contratados (activación manual tras verificar el pago) ────────────
create table public.venue_subscriptions (
  id           bigint generated always as identity primary key,
  venue_id     uuid not null references public.venues(id),
  plan         public.plan_type not null,
  payment_note text not null check (char_length(btrim(payment_note)) between 3 and 300),
  activated_at timestamptz not null default now(),
  activated_by uuid not null references public.profiles(id),
  ended_at     timestamptz,
  ended_by     uuid references public.profiles(id),
  end_reason   text check (char_length(end_reason) <= 300)
);
create unique index venue_subscriptions_one_active on public.venue_subscriptions (venue_id) where ended_at is null;
alter table public.venue_subscriptions enable row level security;
create policy venue_subscriptions_select on public.venue_subscriptions for select to authenticated
  using ((select private.is_super_admin())
         or exists (select 1 from public.venues v where v.id = venue_id and v.owner_id = (select auth.uid())));
grant select on public.venue_subscriptions to authenticated;

create table public.venue_commercial_log (
  id         bigint generated always as identity primary key,
  venue_id   uuid not null references public.venues(id),
  actor_id   uuid references public.profiles(id),
  action     text not null check (action in ('trial_assigned','trial_activated','plan_activated','plan_ended')),
  plan       public.plan_type,
  note       text check (char_length(note) <= 300),
  created_at timestamptz not null default now()
);
alter table public.venue_commercial_log enable row level security;
create policy venue_commercial_log_select on public.venue_commercial_log for select to authenticated
  using ((select private.is_super_admin())
         or exists (select 1 from public.venues v where v.id = venue_id and v.owner_id = (select auth.uid())));
grant select on public.venue_commercial_log to authenticated;
create trigger venue_commercial_log_immutable before update or delete on public.venue_commercial_log
  for each row execute function private.block_audit_mutation();

-- ── Estado comercial (única fuente de verdad, hora del servidor) ─────────────
create or replace function private.commercial_state(p_owner uuid) returns text
language sql stable security definer set search_path = '' as $$
  select case
    when v.id is null then 'none'
    when exists (select 1 from public.venue_subscriptions s where s.venue_id = v.id and s.ended_at is null) then 'subscribed'
    when t.ends_at > now() then 'trial'
    when t.ends_at is not null then 'trial_expired'
    when exists (select 1 from public.venue_subscriptions s where s.venue_id = v.id) then 'plan_ended'
    else 'none'
  end
  from (select 1) d
  left join public.venues v on v.owner_id = p_owner
  left join public.venue_trials t on t.venue_id = v.id
$$;

create or replace function private.can_sell(p_owner uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select not coalesce((select commercial_gate from public.platform_settings where id), false)
      or private.commercial_state(p_owner) in ('subscribed', 'trial')
$$;

-- Control de acceso: bloqueado solo para locales que nunca tuvieron prueba ni plan.
-- Tras vencer se mantiene (las entradas ya vendidas deben poder ingresar).
create or replace function private.can_control_access(p_owner uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select not coalesce((select commercial_gate from public.platform_settings where id), false)
      or private.commercial_state(p_owner) <> 'none'
$$;
revoke all on function private.commercial_state(uuid), private.can_sell(uuid),
  private.can_control_access(uuid) from public, anon, authenticated;

-- Publicar (borrador → activo) exige prueba vigente o plan.
create or replace function private.guard_publish() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if old.status = 'draft' and new.status = 'active' and auth.uid() is not null
     and not private.can_sell(new.owner_id) then
    raise exception 'commercial_inactive' using errcode = 'P0001';
  end if;
  return new;
end $$;
create trigger events_publish_guard before update of status on public.events
  for each row execute function private.guard_publish();

-- Nuevas reservas/ventas y emisión manual exigen autorización comercial. Las entradas
-- de pedidos ya creados (aprobación de pagos pendientes) NO se bloquean.
create or replace function private.guard_commercial() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_owner uuid;
begin
  if tg_table_name = 'tickets' and (to_jsonb(new) ->> 'order_id') is not null then return new; end if;
  select owner_id into v_owner from public.events where id = new.event_id;
  if not private.can_sell(v_owner) then
    if tg_table_name = 'orders' then raise exception 'event_not_available' using errcode = 'P0001'; end if;
    raise exception 'commercial_inactive' using errcode = 'P0001';
  end if;
  return new;
end $$;
create trigger orders_commercial_guard before insert on public.orders
  for each row execute function private.guard_commercial();
create trigger tickets_commercial_guard before insert on public.tickets
  for each row execute function private.guard_commercial();

create or replace function private.guard_checkin() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_owner uuid;
begin
  if new.status = 'used' and old.status <> 'used' then
    select owner_id into v_owner from public.events where id = new.event_id;
    if not private.can_control_access(v_owner) then
      raise exception 'commercial_inactive' using errcode = 'P0001';
    end if;
  end if;
  return new;
end $$;
create trigger tickets_checkin_commercial_guard before update of status on public.tickets
  for each row execute function private.guard_checkin();
revoke all on function private.guard_publish(), private.guard_commercial(), private.guard_checkin()
  from public, anon, authenticated;

-- El catálogo público solo ofrece eventos de locales autorizados a vender.
create or replace function public.public_events() returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(x order by x ->> 'starts_at'), '[]'::jsonb)
  from (
    select jsonb_build_object(
      'id', e.id, 'name', e.name, 'description', e.description,
      'starts_at', e.starts_at, 'ends_at', e.ends_at, 'status', e.status,
      'venue_id', v.id, 'venue_name', v.name, 'venue_zone', v.zone,
      'types', (select jsonb_agg(jsonb_build_object(
                  'id', t.id, 'name', t.name, 'description', t.description, 'price', t.price,
                  'capacity', t.capacity, 'max_per_order', t.max_per_order,
                  'available', greatest(least(t.capacity - private.held_seats(t.id),
                                              e.capacity - private.event_committed(e.id)), 0))
                order by t.position, t.price)
                from public.ticket_types t where t.event_id = e.id and t.active)
    ) as x
    from public.events e
    join public.profiles p on p.id = e.owner_id and p.status = 'active'
    left join public.venues v on v.owner_id = e.owner_id
    where e.status in ('active','live') and e.ends_at > now()
      and private.can_sell(e.owner_id)
      and exists (select 1 from public.ticket_types t where t.event_id = e.id and t.active)
  ) s
$$;

-- ── Estado y activación de la prueba ─────────────────────────────────────────
create or replace function public.trial_status() returns jsonb
language sql stable security definer set search_path = '' as $$
  select case
    when v.id is null then null
    when s.id is not null then jsonb_build_object('state', 'subscribed', 'plan', s.plan,
      'days_left', 0, 'ends_at', null, 'gate', g.commercial_gate)
    when t.venue_id is not null then jsonb_build_object(
      'started_at', t.started_at, 'ends_at', t.ends_at, 'gate', g.commercial_gate,
      'state', case when now() >= t.ends_at then 'expired'
                    when t.ends_at - now() <= interval '3 days' then 'expiring' else 'active' end,
      'days_left', greatest(0, ceil(extract(epoch from (t.ends_at - now())) / 86400)::int))
    when exists (select 1 from public.venue_subscriptions x where x.venue_id = v.id) then
      jsonb_build_object('state', 'plan_ended', 'days_left', 0, 'ends_at', null, 'gate', g.commercial_gate)
    else null end
  from (select 1) d
  left join public.venues v on v.owner_id = auth.uid()
  left join public.venue_trials t on t.venue_id = v.id
  left join public.venue_subscriptions s on s.venue_id = v.id and s.ended_at is null
  left join public.platform_settings g on g.id
$$;

create or replace function public.start_trial() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_venue uuid; v_now timestamptz := date_trunc('milliseconds', now());
begin
  if v_uid is null or private.current_user_role() is distinct from 'admin' then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  select id into v_venue from public.venues where owner_id = v_uid;
  if v_venue is null then
    raise exception 'venue_required' using errcode = 'P0001';
  end if;
  insert into public.venue_trials (venue_id, started_at, ends_at, owner_id)
  values (v_venue, v_now, v_now + interval '14 days', v_uid)
  on conflict (venue_id) do nothing;
  if found then
    insert into public.venue_commercial_log (venue_id, actor_id, action) values (v_venue, v_uid, 'trial_activated');
  end if;
  return public.trial_status();
end $$;

-- ── Superadministrador: asignar prueba o plan ────────────────────────────────
create or replace function public.superadmin_assign_plan(p_owner_id uuid, p_plan public.plan_type, p_note text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_venue uuid; v_note text := btrim(coalesce(p_note, ''));
begin
  if v_uid is null or not private.is_super_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  select id into v_venue from public.venues where owner_id = p_owner_id for update;
  if v_venue is null then raise exception 'venue_required' using errcode = 'P0001'; end if;
  if char_length(v_note) < 3 then raise exception 'payment_note_required' using errcode = 'P0001'; end if;
  update public.venue_subscriptions set ended_at = now(), ended_by = v_uid, end_reason = 'Reemplazado por un nuevo plan'
   where venue_id = v_venue and ended_at is null;
  insert into public.venue_subscriptions (venue_id, plan, payment_note, activated_by)
  values (v_venue, p_plan, left(v_note, 300), v_uid);
  update public.profiles set plan = p_plan where id = p_owner_id;
  insert into public.venue_commercial_log (venue_id, actor_id, action, plan, note)
  values (v_venue, v_uid, 'plan_activated', p_plan, left(v_note, 300));
  return jsonb_build_object('result', 'ok', 'plan', p_plan);
end $$;

create or replace function public.superadmin_end_plan(p_owner_id uuid, p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_venue uuid; v_plan public.plan_type; v_reason text := btrim(coalesce(p_reason, ''));
begin
  if v_uid is null or not private.is_super_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  if char_length(v_reason) < 3 then raise exception 'reason_required' using errcode = 'P0001'; end if;
  select id into v_venue from public.venues where owner_id = p_owner_id;
  update public.venue_subscriptions set ended_at = now(), ended_by = v_uid, end_reason = left(v_reason, 300)
   where venue_id = v_venue and ended_at is null returning plan into v_plan;
  if not found then raise exception 'plan_not_active' using errcode = 'P0001'; end if;
  insert into public.venue_commercial_log (venue_id, actor_id, action, plan, note)
  values (v_venue, v_uid, 'plan_ended', v_plan, left(v_reason, 300));
end $$;

-- Asignar "prueba" no la inicia: el local la activa manualmente, una sola vez.
create or replace function public.superadmin_assign_trial(p_owner_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_venue uuid;
begin
  if v_uid is null or not private.is_super_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  select id into v_venue from public.venues where owner_id = p_owner_id;
  if v_venue is null then raise exception 'venue_required' using errcode = 'P0001'; end if;
  if exists (select 1 from public.venue_trials where venue_id = v_venue) then
    raise exception 'trial_already_used' using errcode = 'P0001';
  end if;
  insert into public.venue_commercial_log (venue_id, actor_id, action) values (v_venue, v_uid, 'trial_assigned');
end $$;

create or replace function public.superadmin_commercial_overview() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or not private.is_super_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  return (select coalesce(jsonb_agg(jsonb_build_object(
            'owner_id', v.owner_id, 'venue_name', v.name, 'state', private.commercial_state(v.owner_id),
            'plan', s.plan, 'trial_ends_at', t.ends_at) order by v.name), '[]'::jsonb)
          from public.venues v
          left join public.venue_trials t on t.venue_id = v.id
          left join public.venue_subscriptions s on s.venue_id = v.id and s.ended_at is null);
end $$;

revoke all on function public.superadmin_assign_plan(uuid, public.plan_type, text),
  public.superadmin_end_plan(uuid, text), public.superadmin_assign_trial(uuid),
  public.superadmin_commercial_overview() from public, anon;
grant execute on function public.superadmin_assign_plan(uuid, public.plan_type, text),
  public.superadmin_end_plan(uuid, text), public.superadmin_assign_trial(uuid),
  public.superadmin_commercial_overview() to authenticated;

-- ── Avisos de vencimiento (7, 3, 1 días y al vencer) ─────────────────────────
-- La cola registra el estado de envío y evita duplicados. El envío por correo lo
-- hará un proveedor SMTP/API que todavía no está contratado (queda 'pending').
create table public.trial_notifications (
  venue_id     uuid not null references public.venues(id),
  kind         text not null check (kind in ('d7','d3','d1','expired')),
  due_at       timestamptz not null,
  email_status text not null default 'pending' check (email_status in ('pending','sent','failed','skipped')),
  attempts     int not null default 0,
  last_error   text check (char_length(last_error) <= 500),
  sent_at      timestamptz,
  created_at   timestamptz not null default now(),
  primary key (venue_id, kind)
);
alter table public.trial_notifications enable row level security;
create policy trial_notifications_select on public.trial_notifications for select to authenticated
  using ((select private.is_super_admin())
         or exists (select 1 from public.venues v where v.id = venue_id and v.owner_id = (select auth.uid())));
grant select on public.trial_notifications to authenticated;

create or replace function private.enqueue_trial_notifications(p_now timestamptz default now()) returns int
language plpgsql security definer set search_path = '' as $$
declare v_count int;
begin
  with due as (
    select t.venue_id, k.kind, t.ends_at - k.before as due_at
    from public.venue_trials t
    cross join (values ('d7', interval '7 days'), ('d3', interval '3 days'),
                       ('d1', interval '1 day'), ('expired', interval '0')) as k(kind, before)
    where t.ends_at - k.before <= p_now
      and not exists (select 1 from public.venue_subscriptions s where s.venue_id = t.venue_id and s.ended_at is null)
  ), ranked as (
    -- Si el proceso estuvo detenido solo se envía el aviso más reciente; los atrasados se omiten.
    select d.*, row_number() over (partition by d.venue_id order by d.due_at desc) as rn from due d
  )
  insert into public.trial_notifications (venue_id, kind, due_at, email_status)
  select venue_id, kind, due_at, case when rn = 1 then 'pending' else 'skipped' end from ranked
  on conflict (venue_id, kind) do nothing;
  get diagnostics v_count = row_count;
  -- Un plan contratado cancela los avisos que aún no salieron.
  update public.trial_notifications n set email_status = 'skipped'
   where n.email_status = 'pending'
     and exists (select 1 from public.venue_subscriptions s where s.venue_id = n.venue_id and s.ended_at is null);
  return v_count;
end $$;
revoke all on function private.enqueue_trial_notifications(timestamptz) from public, anon, authenticated;

create extension if not exists pg_cron;
select cron.schedule('trial-notifications', '17 * * * *', 'select private.enqueue_trial_notifications()');
