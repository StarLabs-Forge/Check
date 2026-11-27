-- 14 · Auditoría de estados de evento, prueba gratuita de 14 días,
--      categorías de entrada (descripción/activa) y límite de órdenes por teléfono.
-- Aditiva: no elimina ni reescribe datos existentes.

-- ── 1. Auditoría de cambios de estado de eventos ────────────────────────────
create table public.event_status_log (
  id             bigint generated always as identity primary key,
  event_id       uuid not null references public.events(id),
  owner_id       uuid not null references public.profiles(id),
  actor_id       uuid references public.profiles(id),
  old_status     public.event_status not null,
  new_status     public.event_status not null,
  reason         text check (char_length(reason) <= 300),
  tickets_sold   int  not null default 0,
  orders_pending int  not null default 0,
  created_at     timestamptz not null default now()
);
create index event_status_log_event_idx on public.event_status_log (event_id, created_at desc);
alter table public.event_status_log enable row level security;
create policy event_status_log_select on public.event_status_log
  for select to authenticated using (owner_id = (select auth.uid()));
grant select on public.event_status_log to authenticated;
create trigger event_status_log_immutable
  before update or delete on public.event_status_log
  for each row execute function private.block_audit_mutation();

create or replace function private.log_event_status() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_sold int; v_pend int; v_reason text;
begin
  if new.status is not distinct from old.status then return new; end if;
  select count(*) into v_sold from public.tickets t where t.event_id = new.id and t.status <> 'cancelled';
  select count(*) into v_pend from public.orders o
   where o.event_id = new.id
     and (o.status = 'verifying' or (o.status = 'awaiting_payment' and o.expires_at > now()));
  v_reason := nullif(btrim(coalesce(current_setting('check.status_reason', true), '')), '');
  insert into public.event_status_log (event_id, owner_id, actor_id, old_status, new_status, reason, tickets_sold, orders_pending)
  values (new.id, new.owner_id, auth.uid(), old.status, new.status, v_reason, v_sold, v_pend);
  return new;
end $$;
create trigger events_status_log after update of status on public.events
  for each row execute function private.log_event_status();

-- Cambio de estado con motivo. Las transiciones válidas las sigue imponiendo
-- private.guard_event (trigger BEFORE UPDATE); esta función solo añade el motivo.
-- Pasar de activo a borrador con entradas vendidas o pedidos pendientes exige motivo.
create or replace function public.set_event_status(p_event_id uuid, p_status public.event_status, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); e public.events; v_sold int; v_pend int; v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
begin
  if v_uid is null or not private.owns_event(p_event_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  select * into e from public.events where id = p_event_id for update;
  select count(*) into v_sold from public.tickets t where t.event_id = e.id and t.status <> 'cancelled';
  select count(*) into v_pend from public.orders o
   where o.event_id = e.id and (o.status = 'verifying' or (o.status = 'awaiting_payment' and o.expires_at > now()));
  if e.status = 'active' and p_status = 'draft' and (v_sold > 0 or v_pend > 0) and v_reason is null then
    raise exception 'reason_required' using errcode = 'P0001',
      hint = 'Hay ' || v_sold || ' entradas y ' || v_pend || ' pedidos pendientes.';
  end if;
  perform set_config('check.status_reason', coalesce(left(v_reason, 300), ''), true);
  update public.events set status = p_status where id = p_event_id;
  return jsonb_build_object('status', p_status, 'tickets_sold', v_sold, 'orders_pending', v_pend);
end $$;
revoke execute on function public.set_event_status(uuid, public.event_status, text) from public, anon;
grant execute on function public.set_event_status(uuid, public.event_status, text) to authenticated;

-- ── 2. Prueba gratuita de 14 días (estado calculado en el servidor) ──────────
create table public.venue_trials (
  owner_id   uuid primary key references public.profiles(id),
  started_at timestamptz not null default now(),
  ends_at    timestamptz not null,
  constraint venue_trials_14_days check (ends_at = started_at + interval '14 days')
);
alter table public.venue_trials enable row level security;
create policy venue_trials_select on public.venue_trials
  for select to authenticated using (owner_id = (select auth.uid()));
grant select on public.venue_trials to authenticated;   -- sin INSERT/UPDATE/DELETE para el cliente
create trigger venue_trials_immutable
  before update or delete on public.venue_trials
  for each row execute function private.block_audit_mutation();

create or replace function public.trial_status() returns jsonb
language sql stable security definer set search_path = '' as $$
  select case when t.owner_id is null then null else jsonb_build_object(
    'started_at', t.started_at, 'ends_at', t.ends_at,
    'state', case when now() >= t.ends_at then 'expired'
                  when t.ends_at - now() <= interval '3 days' then 'expiring' else 'active' end,
    'days_left', greatest(0, ceil(extract(epoch from (t.ends_at - now())) / 86400)::int)) end
  from (select 1) d left join public.venue_trials t on t.owner_id = auth.uid()
$$;

-- Activa la prueba una sola vez, cuando el local ya tiene su registro (venues).
-- Es idempotente: si ya existe devuelve su estado sin reiniciar el periodo.
create or replace function public.start_trial() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null or private.current_user_role() <> 'admin' then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if not exists (select 1 from public.venues where owner_id = v_uid) then
    raise exception 'venue_required' using errcode = 'P0001';
  end if;
  insert into public.venue_trials (owner_id, started_at, ends_at)
  values (v_uid, date_trunc('milliseconds', now()), date_trunc('milliseconds', now()) + interval '14 days')
  on conflict (owner_id) do nothing;
  return public.trial_status();
end $$;
revoke execute on function public.trial_status(), public.start_trial() from public, anon;
grant execute on function public.trial_status(), public.start_trial() to authenticated;

-- ── 3. Categorías de entrada: descripción y disponibilidad ───────────────────
alter table public.ticket_types
  add column description text check (char_length(description) <= 200),
  add column active boolean not null default true;
grant insert (description, active), update (description, active) on public.ticket_types to authenticated;

create or replace function public.public_events() returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(x order by x ->> 'starts_at'), '[]'::jsonb)
  from (
    select jsonb_build_object(
      'id', e.id, 'name', e.name, 'description', e.description,
      'starts_at', e.starts_at, 'ends_at', e.ends_at, 'status', e.status,
      'venue_name', v.name, 'venue_zone', v.zone,
      'types', (select jsonb_agg(jsonb_build_object(
                  'id', t.id, 'name', t.name, 'description', t.description, 'price', t.price,
                  'capacity', t.capacity, 'max_per_order', t.max_per_order,
                  'available', greatest(t.capacity - private.held_seats(t.id), 0))
                order by t.position, t.price)
                from public.ticket_types t where t.event_id = e.id and t.active)
    ) as x
    from public.events e
    join public.profiles p on p.id = e.owner_id and p.status = 'active'
    left join public.venues v on v.owner_id = e.owner_id
    where e.status in ('active','live') and e.ends_at > now()
      and exists (select 1 from public.ticket_types t where t.event_id = e.id and t.active)
  ) s
$$;

-- ── 4. create_order: categoría activa y máximo 3 órdenes activas por teléfono ─
create or replace function public.create_order(p_event_id uuid, p_buyer_name text, p_buyer_ci text,
                                               p_buyer_phone text, p_buyer_email text, p_lines jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  e public.events; v public.venues; t public.ticket_types;
  x jsonb; v_ids uuid[]; v_qty int; v_total numeric(10,2) := 0; v_total_qty int := 0;
  v_max int; v_used int; v_token text; v_id uuid; v_num text; v_exp timestamptz; v_phone text;
begin
  perform private.expire_stale_orders();

  p_buyer_name  := btrim(coalesce(p_buyer_name, ''));
  p_buyer_ci    := btrim(coalesce(p_buyer_ci, ''));
  p_buyer_phone := btrim(coalesce(p_buyer_phone, ''));
  p_buyer_email := nullif(btrim(coalesce(p_buyer_email, '')), '');
  if char_length(p_buyer_name) not between 2 and 120 then raise exception 'invalid_buyer_name' using errcode = 'P0001'; end if;
  if char_length(p_buyer_ci) not between 4 and 20 then raise exception 'invalid_buyer_ci' using errcode = 'P0001'; end if;
  if char_length(p_buyer_phone) not between 6 and 30 then raise exception 'invalid_buyer_phone' using errcode = 'P0001'; end if;
  if p_buyer_email is not null and (char_length(p_buyer_email) > 200
     or p_buyer_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$') then
    raise exception 'invalid_buyer_email' using errcode = 'P0001';
  end if;

  if p_lines is null or jsonb_typeof(p_lines) <> 'array'
     or jsonb_array_length(p_lines) not between 1 and 6 then
    raise exception 'invalid_lines' using errcode = 'P0001';
  end if;
  for x in select * from jsonb_array_elements(p_lines) loop
    if jsonb_typeof(x) <> 'object'
       or coalesce(x ->> 'type_id', '') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
       or coalesce(x ->> 'qty', '') !~ '^[0-9]{1,2}$' then
      raise exception 'invalid_lines' using errcode = 'P0001';
    end if;
  end loop;
  select array_agg(distinct (y ->> 'type_id')::uuid) into v_ids from jsonb_array_elements(p_lines) y;
  if coalesce(array_length(v_ids, 1), 0) <> jsonb_array_length(p_lines) then
    raise exception 'invalid_lines' using errcode = 'P0001';
  end if;

  select * into e from public.events where id = p_event_id;
  if not found or e.status not in ('active','live') or e.ends_at <= now()
     or not exists (select 1 from public.profiles where id = e.owner_id and status = 'active') then
    raise exception 'event_not_available' using errcode = 'P0001';
  end if;

  select * into v from public.venues where owner_id = e.owner_id;
  if not found or coalesce(btrim(v.bank_beneficiary), '') = ''
     or (coalesce(btrim(v.bank_account), '') = '' and coalesce(btrim(v.bank_qr_path), '') = '') then
    raise exception 'venue_payment_not_configured' using errcode = 'P0001';
  end if;

  perform 1 from public.profiles where id = e.owner_id for update;
  perform 1 from public.ticket_types where id = any (v_ids) and event_id = p_event_id order by id for update;
  if (select count(*) from public.ticket_types where id = any (v_ids) and event_id = p_event_id and active)
     <> array_length(v_ids, 1) then
    raise exception 'invalid_ticket_type' using errcode = 'P0001';
  end if;

  -- Regla V1: máximo 3 órdenes activas por número de teléfono (normalizado, en toda la plataforma).
  -- El bloqueo consultivo evita que dos solicitudes simultáneas superen el límite.
  v_phone := regexp_replace(p_buyer_phone, '[^0-9]', '', 'g');
  perform pg_advisory_xact_lock(hashtextextended('order_phone:' || v_phone, 0));
  if (select count(*) from public.orders o
      where regexp_replace(o.buyer_phone, '[^0-9]', '', 'g') = v_phone
        and (o.status = 'verifying' or (o.status = 'awaiting_payment' and o.expires_at > now()))) >= 3 then
    raise exception 'too_many_open_orders' using errcode = 'P0001';
  end if;

  for x in select * from jsonb_array_elements(p_lines) loop
    select * into t from public.ticket_types where id = (x ->> 'type_id')::uuid;
    v_qty := (x ->> 'qty')::int;
    if v_qty < 1 or v_qty > t.max_per_order then
      raise exception 'invalid_quantity' using errcode = 'P0001', hint = t.name;
    end if;
    if t.capacity - private.held_seats(t.id) < v_qty then
      raise exception 'sold_out' using errcode = 'P0001', hint = t.name;
    end if;
    v_total := v_total + t.price * v_qty;
    v_total_qty := v_total_qty + v_qty;
  end loop;
  if v_total <= 0 then raise exception 'order_total_zero' using errcode = 'P0001'; end if;

  select pl.max_tickets_month into v_max
  from public.profiles p join public.plan_limits pl on pl.plan = p.plan where p.id = e.owner_id;
  if v_max is not null then
    select
      (select count(*) from public.tickets tk join public.events ev on ev.id = tk.event_id
        where ev.owner_id = e.owner_id and tk.status <> 'cancelled'
          and date_trunc('month', tk.created_at at time zone 'America/La_Paz')
            = date_trunc('month', now() at time zone 'America/La_Paz'))
      + (select coalesce(sum(l.qty), 0) from public.order_lines l
          join public.orders o on o.id = l.order_id
          join public.events ev on ev.id = o.event_id
          where ev.owner_id = e.owner_id
            and (o.status = 'verifying' or (o.status = 'awaiting_payment' and o.expires_at > now())))
    into v_used;
    if v_used + v_total_qty > v_max then
      raise exception 'plan_limit_tickets' using errcode = 'P0001';
    end if;
  end if;

  v_token := encode(extensions.gen_random_bytes(32), 'hex');
  insert into public.orders (event_id, buyer_name, buyer_ci, buyer_phone, buyer_email, total)
  values (p_event_id, p_buyer_name, p_buyer_ci, p_buyer_phone, p_buyer_email, v_total)
  returning id, number, expires_at into v_id, v_num, v_exp;

  insert into public.order_secrets (order_id, token_hash)
  values (v_id, encode(extensions.digest(v_token, 'sha256'), 'hex'));

  insert into public.order_lines (order_id, ticket_type_id, qty, unit_price)
  select v_id, tt.id, y.qty, tt.price
  from jsonb_to_recordset(p_lines) as y(type_id uuid, qty int)
  join public.ticket_types tt on tt.id = y.type_id;

  return jsonb_build_object('order_id', v_id, 'number', v_num, 'token', v_token,
                            'total', v_total, 'expires_at', v_exp);
end $$;
