-- 16 · Límite de 3 pedidos activos por teléfono con normalización nacional/internacional.
-- Corrige: "+591 7111 1111" y "71111111" contaban como teléfonos distintos.

create or replace function private.normalize_phone(p_phone text) returns text
language plpgsql immutable set search_path = '' as $$
declare d text := regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g');
begin
  if left(d, 2) = '00' then d := substr(d, 3); end if;                       -- 00 591 ...
  if length(d) = 11 and left(d, 3) = '591' then d := substr(d, 4); end if;   -- código de Bolivia
  if length(d) = 9 and left(d, 1) = '0' then d := substr(d, 2); end if;      -- prefijo troncal 0
  return d;
end $$;
revoke all on function private.normalize_phone(text) from public, anon, authenticated;

create index if not exists orders_open_phone_idx on public.orders (private.normalize_phone(buyer_phone))
  where status in ('awaiting_payment', 'verifying');

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
  v_phone       := private.normalize_phone(p_buyer_phone);
  if char_length(p_buyer_name) not between 2 and 120 then raise exception 'invalid_buyer_name' using errcode = 'P0001'; end if;
  if char_length(p_buyer_ci) not between 4 and 20 then raise exception 'invalid_buyer_ci' using errcode = 'P0001'; end if;
  if char_length(p_buyer_phone) not between 6 and 30 or char_length(v_phone) < 6 then
    raise exception 'invalid_buyer_phone' using errcode = 'P0001';
  end if;
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

  -- Serializa por local (cupos y límite de plan) y por categoría
  perform 1 from public.profiles where id = e.owner_id for update;
  perform 1 from public.ticket_types where id = any (v_ids) and event_id = p_event_id order by id for update;
  if (select count(*) from public.ticket_types where id = any (v_ids) and event_id = p_event_id and active)
     <> array_length(v_ids, 1) then
    raise exception 'invalid_ticket_type' using errcode = 'P0001';
  end if;

  -- Regla V1: máximo 3 pedidos activos por teléfono en toda la plataforma. El bloqueo
  -- consultivo serializa solicitudes simultáneas del mismo teléfono entre locales distintos.
  perform pg_advisory_xact_lock(hashtextextended('order_phone:' || v_phone, 0));
  if (select count(*) from public.orders o
      where private.normalize_phone(o.buyer_phone) = v_phone
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
