-- 07 · RPC de pedidos públicos, decisión de pagos y verificadores delegados.
-- Todo SECURITY DEFINER con search_path vacío; la validación va dentro.

create function private.held_seats(p_type_id uuid) returns integer
language sql stable security definer set search_path = '' as $$
  select coalesce(sum(l.qty), 0)::int
  from public.order_lines l join public.orders o on o.id = l.order_id
  where l.ticket_type_id = p_type_id
    and (o.status in ('verifying','approved')
         or (o.status = 'awaiting_payment' and o.expires_at > now()))
$$;

create function private.expire_stale_orders() returns void
language sql security definer set search_path = '' as $$
  update public.orders set status = 'expired'
  where status = 'awaiting_payment' and expires_at <= now()
$$;
revoke all on function private.held_seats(uuid), private.expire_stale_orders() from public, anon, authenticated;

-- ───────── Catálogo público ─────────
create function public.public_events() returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(x order by x ->> 'starts_at'), '[]'::jsonb)
  from (
    select jsonb_build_object(
      'id', e.id, 'name', e.name, 'description', e.description,
      'starts_at', e.starts_at, 'ends_at', e.ends_at, 'status', e.status,
      'venue_name', v.name, 'venue_zone', v.zone,
      'types', (select jsonb_agg(jsonb_build_object(
                  'id', t.id, 'name', t.name, 'price', t.price, 'capacity', t.capacity,
                  'max_per_order', t.max_per_order,
                  'available', greatest(t.capacity - private.held_seats(t.id), 0))
                order by t.position, t.price)
                from public.ticket_types t where t.event_id = e.id)
    ) as x
    from public.events e
    join public.profiles p on p.id = e.owner_id and p.status = 'active'
    left join public.venues v on v.owner_id = e.owner_id
    where e.status in ('active','live') and e.ends_at > now()
      and exists (select 1 from public.ticket_types t where t.event_id = e.id)
  ) s
$$;

-- ───────── Crear pedido (comprador invitado) ─────────
create function public.create_order(
  p_event_id uuid, p_buyer_name text, p_buyer_ci text, p_buyer_phone text,
  p_buyer_email text, p_lines jsonb
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  e public.events; v public.venues; t public.ticket_types;
  x jsonb; v_ids uuid[]; v_qty int; v_total numeric(10,2) := 0; v_total_qty int := 0;
  v_max int; v_used int; v_token text; v_id uuid; v_num text; v_exp timestamptz;
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

  -- Serializa por local (cupos y límite de plan) y por tipo de entrada
  perform 1 from public.profiles where id = e.owner_id for update;
  perform 1 from public.ticket_types where id = any (v_ids) and event_id = p_event_id order by id for update;
  if (select count(*) from public.ticket_types where id = any (v_ids) and event_id = p_event_id)
     <> array_length(v_ids, 1) then
    raise exception 'invalid_ticket_type' using errcode = 'P0001';
  end if;

  if (select count(*) from public.orders o
      where o.event_id = p_event_id and o.buyer_ci = p_buyer_ci
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

  -- El token en claro se entrega UNA sola vez; en BD solo queda el hash.
  return jsonb_build_object('order_id', v_id, 'number', v_num, 'token', v_token,
                            'total', v_total, 'expires_at', v_exp);
end $$;

-- ───────── Consultar pedido (comprador, con token) ─────────
create function public.get_order(p_order_id uuid, p_token text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  s public.order_secrets; o public.orders; e public.events; v public.venues;
  v_lines jsonb; v_tickets jsonb := '[]'::jsonb; v_bank jsonb := null;
begin
  select * into s from public.order_secrets where order_id = p_order_id;
  if not found or p_token is null
     or s.token_hash <> encode(extensions.digest(p_token, 'sha256'), 'hex') then
    raise exception 'not_found' using errcode = 'P0002';
  end if;

  update public.orders set status = 'expired'
   where id = p_order_id and status = 'awaiting_payment' and expires_at <= now();
  select * into o from public.orders where id = p_order_id;
  select * into e from public.events where id = o.event_id;
  select * into v from public.venues where owner_id = e.owner_id;

  select jsonb_agg(jsonb_build_object('type_name', t.name, 'qty', l.qty, 'unit_price', l.unit_price)
                   order by t.position, t.price)
    into v_lines
  from public.order_lines l join public.ticket_types t on t.id = l.ticket_type_id
  where l.order_id = o.id;

  if o.status in ('awaiting_payment','verifying') then
    v_bank := jsonb_build_object('beneficiary', v.bank_beneficiary, 'bank_name', v.bank_name,
                                 'account', v.bank_account, 'qr_path', v.bank_qr_path);
  end if;

  if o.status = 'approved' then
    select coalesce(jsonb_agg(jsonb_build_object(
             'ticket_id', tk.id, 'type_name', tt.name, 'status', tk.status,
             'qr_token', encode(extensions.hmac(tk.id::text, s.token_hash, 'sha256'), 'hex'))
           order by tk.created_at, tk.id), '[]'::jsonb)
      into v_tickets
    from public.tickets tk join public.ticket_types tt on tt.id = tk.ticket_type_id
    where tk.order_id = o.id;
  end if;

  return jsonb_build_object(
    'order', jsonb_build_object('id', o.id, 'number', o.number, 'status', o.status, 'total', o.total,
                                'buyer_name', o.buyer_name, 'created_at', o.created_at,
                                'expires_at', o.expires_at, 'declared_at', o.declared_at,
                                'decided_at', o.decided_at, 'reject_reason', o.reject_reason),
    'event', jsonb_build_object('id', e.id, 'name', e.name, 'starts_at', e.starts_at),
    'venue', jsonb_build_object('name', v.name, 'zone', v.zone),
    'bank', v_bank, 'lines', coalesce(v_lines, '[]'::jsonb), 'tickets', v_tickets);
end $$;

-- ───────── «Ya pagué» / cancelar (comprador) ─────────
create function public.declare_payment(p_order_id uuid, p_token text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare s public.order_secrets; o public.orders;
begin
  select * into s from public.order_secrets where order_id = p_order_id;
  if not found or p_token is null
     or s.token_hash <> encode(extensions.digest(p_token, 'sha256'), 'hex') then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  select * into o from public.orders where id = p_order_id for update;

  if o.status = 'verifying' then
    return jsonb_build_object('status', o.status);        -- idempotente
  end if;
  if o.status = 'awaiting_payment' and o.expires_at <= now() then
    update public.orders set status = 'expired' where id = o.id;
    raise exception 'order_expired' using errcode = 'P0001';
  end if;
  if o.status <> 'awaiting_payment' then
    raise exception 'order_not_payable' using errcode = 'P0001';
  end if;

  update public.orders set status = 'verifying', declared_at = now() where id = o.id;
  return jsonb_build_object('status', 'verifying');
end $$;

create function public.cancel_order(p_order_id uuid, p_token text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare s public.order_secrets; o public.orders;
begin
  select * into s from public.order_secrets where order_id = p_order_id;
  if not found or p_token is null
     or s.token_hash <> encode(extensions.digest(p_token, 'sha256'), 'hex') then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  select * into o from public.orders where id = p_order_id for update;
  if o.status <> 'awaiting_payment' then
    raise exception 'order_not_cancellable' using errcode = 'P0001';
  end if;
  update public.orders set status = 'cancelled' where id = o.id;
  return jsonb_build_object('status', 'cancelled');
end $$;

-- ───────── Decidir pago (admin o verificador delegado) ─────────
create function public.decide_order(p_order_id uuid, p_approve boolean, p_reason text default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid(); o public.orders; s public.order_secrets; e public.events;
  v_perm text; v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  l record; i int; v_tid uuid; v_qr text;
begin
  if v_uid is null then raise exception 'forbidden' using errcode = '42501'; end if;
  select * into o from public.orders where id = p_order_id for update;
  if not found or not private.can_verify_payments(o.event_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  select * into e from public.events where id = o.event_id;
  v_perm := case when private.owns_event(o.event_id) then 'admin' else 'verifier' end;

  if o.status = 'awaiting_payment' and o.expires_at <= now() then
    update public.orders set status = 'expired' where id = o.id;
    o.status := 'expired';
  end if;

  -- Ya decidido por otra persona (o nunca declarado): conflicto, sin cambios
  if o.status <> 'verifying' then
    insert into public.audit_log (owner_id, actor_id, actor_permission, action, result, order_id)
    values (e.owner_id, v_uid, v_perm, 'payment_conflict', o.status::text, o.id);
    return jsonb_build_object('result', 'conflict', 'status', o.status);
  end if;

  if p_approve then
    select * into s from public.order_secrets where order_id = o.id;
    for l in select ol.ticket_type_id, ol.qty from public.order_lines ol where ol.order_id = o.id loop
      for i in 1 .. l.qty loop
        v_tid := gen_random_uuid();
        v_qr  := encode(extensions.hmac(v_tid::text, s.token_hash, 'sha256'), 'hex');
        insert into public.tickets (id, event_id, guest_name, guest_phone, qr_token_hash,
                                    payment_status, payment_confirmed_at, payment_confirmed_by,
                                    created_by, order_id, ticket_type_id)
        values (v_tid, o.event_id, o.buyer_name, o.buyer_phone,
                encode(extensions.digest(v_qr, 'sha256'), 'hex'),
                'paid', now(), v_uid, v_uid, o.id, l.ticket_type_id);
      end loop;
    end loop;
    update public.orders set status = 'approved', decided_at = now(), decided_by = v_uid where id = o.id;
    insert into public.audit_log (owner_id, actor_id, actor_permission, action, result, order_id)
    values (e.owner_id, v_uid, v_perm, 'order_approved', 'ok', o.id);
    return jsonb_build_object('result', 'ok', 'status', 'approved');
  end if;

  if v_reason is null then raise exception 'reason_required' using errcode = 'P0001'; end if;
  update public.orders
     set status = 'rejected', decided_at = now(), decided_by = v_uid, reject_reason = left(v_reason, 300)
   where id = o.id;
  insert into public.audit_log (owner_id, actor_id, actor_permission, action, result, order_id, reason)
  values (e.owner_id, v_uid, v_perm, 'order_rejected', 'ok', o.id, left(v_reason, 300));
  return jsonb_build_object('result', 'ok', 'status', 'rejected');
end $$;

-- ───────── Delegar / quitar verificador ─────────
create function public.grant_payment_verifier(p_verifier_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null or private.current_user_role() is distinct from 'admin' then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  -- Solo staff que ya canjeó su código en un evento de este local
  if not exists (select 1 from public.event_staff es join public.events e on e.id = es.event_id
                 where es.staff_id = p_verifier_id and e.owner_id = v_uid
                   and es.redeemed_at is not null and es.revoked_at is null) then
    raise exception 'not_your_staff' using errcode = 'P0001';
  end if;
  insert into public.payment_verifiers (owner_id, verifier_id) values (v_uid, p_verifier_id)
  on conflict (owner_id, verifier_id) where revoked_at is null do nothing;
  if found then
    insert into public.audit_log (owner_id, actor_id, actor_permission, action, result)
    values (v_uid, v_uid, 'admin', 'verifier_granted', 'ok');
  end if;
end $$;

create function public.revoke_payment_verifier(p_verifier_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null or private.current_user_role() is distinct from 'admin' then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  update public.payment_verifiers set revoked_at = now()
   where owner_id = v_uid and verifier_id = p_verifier_id and revoked_at is null;
  if not found then raise exception 'verifier_not_found' using errcode = 'P0001'; end if;
  insert into public.audit_log (owner_id, actor_id, actor_permission, action, result)
  values (v_uid, v_uid, 'admin', 'verifier_revoked', 'ok');
end $$;

-- ───────── Permisos de ejecución ─────────
revoke all on function public.public_events(),
  public.create_order(uuid, text, text, text, text, jsonb),
  public.get_order(uuid, text), public.declare_payment(uuid, text), public.cancel_order(uuid, text),
  public.decide_order(uuid, boolean, text),
  public.grant_payment_verifier(uuid), public.revoke_payment_verifier(uuid)
  from public, anon, authenticated;

grant execute on function public.public_events(),
  public.create_order(uuid, text, text, text, text, jsonb),
  public.get_order(uuid, text), public.declare_payment(uuid, text), public.cancel_order(uuid, text)
  to anon, authenticated;
grant execute on function public.decide_order(uuid, boolean, text),
  public.grant_payment_verifier(uuid), public.revoke_payment_verifier(uuid)
  to authenticated;
