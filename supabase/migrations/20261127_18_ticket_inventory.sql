-- 18 · Inventario consistente por categoría: emisión manual, aforo, precios y borrado.
--   · Toda entrada emitida manualmente pertenece a una categoría y descuenta su cupo.
--   · Ventas en línea y manuales comparten la misma definición de cupo comprometido.
--   · La suma de cupos de categorías no supera el aforo del evento.
--   · Solo se elimina una categoría sin historial. Cambios de precio/cupo auditados.

alter table public.tickets add column unit_price numeric(10,2) check (unit_price >= 0);

-- Cupo comprometido por categoría = pedidos vivos + entradas manuales no canceladas.
create or replace function private.held_seats(p_type_id uuid) returns integer
language sql stable security definer set search_path = '' as $$
  select (
    coalesce((select sum(l.qty) from public.order_lines l join public.orders o on o.id = l.order_id
              where l.ticket_type_id = p_type_id
                and (o.status in ('verifying','approved')
                     or (o.status = 'awaiting_payment' and o.expires_at > now()))), 0)
    + (select count(*) from public.tickets t
       where t.ticket_type_id = p_type_id and t.order_id is null and t.status <> 'cancelled')
  )::int
$$;

-- Comprometido en todo el evento (incluye entradas manuales antiguas sin categoría).
create or replace function private.event_committed(p_event_id uuid) returns integer
language sql stable security definer set search_path = '' as $$
  select (
    coalesce((select sum(l.qty) from public.order_lines l join public.orders o on o.id = l.order_id
              where o.event_id = p_event_id
                and (o.status in ('verifying','approved')
                     or (o.status = 'awaiting_payment' and o.expires_at > now()))), 0)
    + (select count(*) from public.tickets t
       where t.event_id = p_event_id and t.order_id is null and t.status <> 'cancelled')
  )::int
$$;

create or replace function private.guard_order_line() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_event uuid; v_cap int;
begin
  select o.event_id, e.capacity into v_event, v_cap
  from public.orders o join public.events e on e.id = o.event_id where o.id = new.order_id;
  if private.event_committed(v_event) > v_cap then
    raise exception 'sold_out' using errcode = 'P0001', hint = 'Aforo del evento completo.';
  end if;
  return null;
end $$;
create trigger order_lines_event_capacity after insert on public.order_lines
  for each row execute function private.guard_order_line();

-- Invariantes de toda entrada nueva, venga de donde venga.
create or replace function private.guard_new_ticket() returns trigger
language plpgsql security definer set search_path = '' as $$
declare e public.events; t public.ticket_types;
begin
  if new.order_id is not null then   -- emitida al aprobar un pago: precio histórico del pedido
    select unit_price into new.unit_price from public.order_lines
     where order_id = new.order_id and ticket_type_id = new.ticket_type_id;
    return new;
  end if;

  if new.ticket_type_id is null then
    raise exception 'ticket_type_required' using errcode = 'P0001';
  end if;
  select * into t from public.ticket_types where id = new.ticket_type_id for update;
  if not found or t.event_id <> new.event_id or not t.active then
    raise exception 'invalid_ticket_type' using errcode = 'P0001';
  end if;
  select * into e from public.events where id = new.event_id for share;
  if e.status in ('finished', 'suspended') then
    raise exception 'event_closed' using errcode = 'P0001';
  end if;
  if t.capacity - private.held_seats(t.id) < 1 then
    raise exception 'sold_out' using errcode = 'P0001', hint = t.name;
  end if;
  if private.event_committed(e.id) + 1 > e.capacity then
    raise exception 'sold_out' using errcode = 'P0001', hint = 'Aforo del evento completo.';
  end if;
  new.unit_price := case when e.access_type = 'free' then 0 else t.price end;
  return new;
end $$;
create trigger tickets_inventory_guard before insert on public.tickets
  for each row execute function private.guard_new_ticket();

-- Emisión manual: ahora exige categoría. La firma antigua se conserva solo para que
-- una app desactualizada reciba un error explícito en lugar de emitir sin descontar cupo.
-- (La firma nueva declara p_ticket_type_id sin valor por defecto: no hay ambigüedad.)
create or replace function public.create_ticket(
  p_event_id uuid, p_guest_name text, p_guest_phone text default null,
  p_payment_status public.payment_status default 'pending'
) returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  raise exception 'ticket_type_required' using errcode = 'P0001',
    hint = 'Actualiza la aplicación: cada entrada pertenece a una categoría.';
end $$;

create function public.create_ticket(
  p_event_id uuid, p_guest_name text, p_ticket_type_id uuid, p_guest_phone text default null,
  p_payment_status public.payment_status default 'pending'
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  e public.events; v_max int; v_count int; v_token text; v_pay public.payment_status; v_id uuid;
begin
  if v_uid is null or not private.owns_event(p_event_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if coalesce(btrim(p_guest_name), '') = '' or char_length(p_guest_name) > 120 then
    raise exception 'invalid_guest_name' using errcode = 'P0001';
  end if;
  if p_ticket_type_id is null then
    raise exception 'ticket_type_required' using errcode = 'P0001';
  end if;

  select * into e from public.events where id = p_event_id;
  if e.status in ('finished', 'suspended') then
    raise exception 'event_closed' using errcode = 'P0001';
  end if;

  -- Mismo orden de bloqueos que create_order: primero el local, luego la categoría.
  perform 1 from public.profiles where id = v_uid for update;

  select pl.max_tickets_month into v_max
  from public.profiles p join public.plan_limits pl on pl.plan = p.plan
  where p.id = v_uid;
  if v_max is not null then
    select count(*) into v_count
    from public.tickets t join public.events ev on ev.id = t.event_id
    where ev.owner_id = v_uid and t.status <> 'cancelled'
      and date_trunc('month', t.created_at at time zone 'America/La_Paz')
        = date_trunc('month', now() at time zone 'America/La_Paz');
    if v_count >= v_max then
      raise exception 'plan_limit_tickets' using errcode = 'P0001',
        hint = 'El plan permite ' || v_max || ' QR por mes.';
    end if;
  end if;

  v_pay := case when e.access_type = 'free' then 'paid' else p_payment_status end;
  v_token := encode(extensions.gen_random_bytes(32), 'hex');

  insert into public.tickets (event_id, ticket_type_id, guest_name, guest_phone, qr_token_hash, payment_status,
                              payment_confirmed_at, payment_confirmed_by, created_by)
  values (p_event_id, p_ticket_type_id, btrim(p_guest_name), nullif(btrim(p_guest_phone), ''),
          encode(extensions.digest(v_token, 'sha256'), 'hex'), v_pay,
          case when v_pay = 'paid' then now() end,
          case when v_pay = 'paid' then v_uid end, v_uid)
  returning id into v_id;

  insert into public.audit_log (owner_id, actor_id, actor_permission, action, result)
  values (v_uid, v_uid, 'admin', 'ticket_issued', 'ok');

  return jsonb_build_object('ticket_id', v_id, 'qr_token', v_token, 'payment_status', v_pay);
end $$;
revoke all on function public.create_ticket(uuid, text, uuid, text, public.payment_status) from public, anon;
grant execute on function public.create_ticket(uuid, text, uuid, text, public.payment_status) to authenticated;

alter table public.audit_log drop constraint audit_log_action_check;
alter table public.audit_log add constraint audit_log_action_check check (action = any (array[
  'order_approved','order_rejected','payment_conflict','verifier_granted','verifier_revoked',
  'staff_created','staff_updated','staff_activated','staff_deactivated','staff_deleted',
  'staff_password_reset','staff_events_changed','ticket_issued']));

-- Cupos: nunca por debajo de lo comprometido; la suma no supera el aforo del evento.
create or replace function private.guard_ticket_type() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_cap int; v_others int;
begin
  -- Bloquea el evento: dos ediciones simultáneas de categorías no pueden superar el aforo.
  select capacity into v_cap from public.events where id = new.event_id for no key update;
  if tg_op = 'UPDATE' and new.capacity < old.capacity and new.capacity < private.held_seats(new.id) then
    raise exception 'capacity_below_sold' using errcode = 'P0001',
      hint = 'Ya hay ' || private.held_seats(new.id) || ' entradas vendidas o reservadas en esta categoría.';
  end if;
  if tg_op = 'INSERT' or new.capacity > old.capacity then
    select coalesce(sum(capacity), 0) into v_others from public.ticket_types
     where event_id = new.event_id and id <> new.id;
    if v_others + new.capacity > v_cap then
      raise exception 'category_capacity_exceeds_event' using errcode = 'P0001',
        hint = 'Disponible dentro del aforo: ' || greatest(v_cap - v_others, 0);
    end if;
  end if;
  return new;
end $$;
-- Reemplaza el guard de la migración 14 (solo cubría reducciones) por el completo.
create or replace trigger ticket_types_capacity_guard before insert or update of capacity on public.ticket_types
  for each row execute function private.guard_ticket_type();

create or replace function private.guard_event_capacity() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.capacity < private.event_committed(new.id) then
    raise exception 'capacity_below_sold' using errcode = 'P0001';
  end if;
  if (select count(*) from public.ticket_types where event_id = new.id) > 1
     and new.capacity < (select sum(capacity) from public.ticket_types where event_id = new.id) then
    raise exception 'category_capacity_exceeds_event' using errcode = 'P0001',
      hint = 'Reduce primero los cupos de las categorías.';
  end if;
  return new;
end $$;
create trigger events_capacity_guard before update of capacity on public.events
  for each row when (new.capacity < old.capacity) execute function private.guard_event_capacity();

-- Solo se eliminan categorías sin historial (reservas, ventas, rechazos, expiraciones, entradas).
create or replace function private.guard_ticket_type_delete() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from public.order_lines where ticket_type_id = old.id)
     or exists (select 1 from public.tickets where ticket_type_id = old.id) then
    raise exception 'category_has_history' using errcode = 'P0001';
  end if;
  return old;
end $$;
create trigger ticket_types_delete_guard before delete on public.ticket_types
  for each row execute function private.guard_ticket_type_delete();

-- Auditoría de categorías (precio, cupo, disponibilidad, alta y baja).
create table public.ticket_type_log (
  id             bigint generated always as identity primary key,
  ticket_type_id uuid not null,             -- sin FK: el registro sobrevive a la baja
  event_id       uuid not null references public.events(id),
  actor_id       uuid references public.profiles(id),
  action         text not null check (action in ('created','updated','deleted')),
  name           text not null,
  old_price      numeric(10,2), new_price numeric(10,2),
  old_capacity   int,           new_capacity int,
  old_active     boolean,       new_active boolean,
  created_at     timestamptz not null default now()
);
create index ticket_type_log_event_idx on public.ticket_type_log (event_id, created_at desc);
alter table public.ticket_type_log enable row level security;
create policy ticket_type_log_select on public.ticket_type_log
  for select to authenticated using (private.owns_event(event_id));
grant select on public.ticket_type_log to authenticated;
create trigger ticket_type_log_immutable before update or delete on public.ticket_type_log
  for each row execute function private.block_audit_mutation();

create or replace function private.log_ticket_type() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    insert into public.ticket_type_log (ticket_type_id, event_id, actor_id, action, name, new_price, new_capacity, new_active)
    values (new.id, new.event_id, auth.uid(), 'created', new.name, new.price, new.capacity, new.active);
  elsif tg_op = 'UPDATE' then
    if (new.price, new.capacity, new.active, new.name) is distinct from (old.price, old.capacity, old.active, old.name) then
      insert into public.ticket_type_log (ticket_type_id, event_id, actor_id, action, name,
        old_price, new_price, old_capacity, new_capacity, old_active, new_active)
      values (new.id, new.event_id, auth.uid(), 'updated', new.name,
        old.price, new.price, old.capacity, new.capacity, old.active, new.active);
    end if;
  else
    insert into public.ticket_type_log (ticket_type_id, event_id, actor_id, action, name, old_price, old_capacity, old_active)
    values (old.id, old.event_id, auth.uid(), 'deleted', old.name, old.price, old.capacity, old.active);
  end if;
  return null;
end $$;
create trigger ticket_types_log after insert or update or delete on public.ticket_types
  for each row execute function private.log_ticket_type();

revoke all on function private.event_committed(uuid), private.guard_order_line(), private.guard_new_ticket(),
  private.guard_ticket_type(), private.guard_event_capacity(), private.guard_ticket_type_delete(),
  private.log_ticket_type() from public, anon, authenticated;

create or replace function public.ticket_type_stats(p_event_id uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', t.id, 'sold', s.sold + m.manual, 'reserved', s.reserved,
           'available', greatest(t.capacity - s.sold - m.manual - s.reserved, 0)) order by t.position, t.price), '[]'::jsonb)
  from public.ticket_types t
  cross join lateral (
    select coalesce(sum(l.qty) filter (where o.status = 'approved'), 0)::int as sold,
           coalesce(sum(l.qty) filter (where o.status = 'verifying'
                      or (o.status = 'awaiting_payment' and o.expires_at > now())), 0)::int as reserved
    from public.order_lines l join public.orders o on o.id = l.order_id
    where l.ticket_type_id = t.id) s
  cross join lateral (
    select count(*)::int as manual from public.tickets k
    where k.ticket_type_id = t.id and k.order_id is null and k.status <> 'cancelled') m
  where t.event_id = p_event_id and private.owns_event(p_event_id)
$$;
