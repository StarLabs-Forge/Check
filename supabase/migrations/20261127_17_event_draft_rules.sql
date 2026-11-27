-- 17 · Reglas aprobadas para volver un evento activo a borrador y QR en borrador.
--   · Permitido solo sin entradas vendidas (pedido aprobado o entrada pagada de un
--     evento de pago) y sin QR utilizados. Las reservas pendientes se permiten.
--   · El motivo es obligatorio siempre.
--   · Las reservas conservan sus 15 minutos; los pagos informados se pueden resolver.
--   · Los QR emitidos en borrador no permiten ingresar (y no se marcan como usados)
--     hasta que el evento vuelva a estar activo.

alter type public.scan_result add value if not exists 'event_inactive';

create or replace function private.require_status_reason() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if not (old.status = 'active' and new.status = 'draft') then return new; end if;

  if exists (select 1 from public.tickets t where t.event_id = new.id
             and (t.status = 'used' or t.checked_in_at is not null)) then
    raise exception 'draft_blocked_used_qr' using errcode = 'P0001',
      hint = 'El evento ya tiene ingresos registrados.';
  end if;
  if exists (select 1 from public.orders o where o.event_id = new.id and o.status = 'approved')
     or exists (select 1 from public.tickets t where t.event_id = new.id and t.status <> 'cancelled'
                and (t.order_id is not null or (old.access_type = 'paid' and t.payment_status = 'paid'))) then
    raise exception 'draft_blocked_sales' using errcode = 'P0001',
      hint = 'El evento ya tiene entradas vendidas.';
  end if;
  if auth.uid() is not null
     and nullif(btrim(coalesce(current_setting('check.status_reason', true), '')), '') is null then
    raise exception 'reason_required' using errcode = 'P0001';
  end if;
  return new;
end $$;

-- Un pedido solo nace si el evento sigue a la venta. El bloqueo compartido sobre el
-- evento serializa la creación con un cambio de estado simultáneo (sin carreras).
create or replace function private.guard_new_order() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_status public.event_status;
begin
  select status into v_status from public.events where id = new.event_id for share;
  if v_status not in ('active', 'live') then
    raise exception 'event_not_available' using errcode = 'P0001';
  end if;
  return new;
end $$;
create trigger orders_event_guard before insert on public.orders
  for each row execute function private.guard_new_order();

-- Emitir una entrada (aprobación de pago o emisión manual) también toma el bloqueo
-- compartido: o la entrada existe antes del cambio a borrador (y lo impide), o se
-- emite después, ya en borrador.
create or replace function private.lock_event_for_ticket() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.events where id = new.event_id for share;
  return new;
end $$;
create trigger tickets_event_lock before insert on public.tickets
  for each row execute function private.lock_event_for_ticket();

-- Quien tiene permiso de puerta, sin mirar el estado del evento (para poder
-- responder "evento no activo" en vez de "sin permiso").
create or replace function private.has_door_role(p_event_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select private.owns_event(p_event_id)
      or (coalesce(private.current_user_role() = 'staff', false)
          and exists (select 1 from public.event_staff es
                      where es.event_id = p_event_id and es.staff_id = (select auth.uid())
                        and es.revoked_at is null)
          and not exists (select 1 from public.staff_accounts sa
                          where sa.staff_id = (select auth.uid())
                            and (not sa.active or not ('scanQr' = any (sa.permissions)))))
$$;
revoke all on function private.has_door_role(uuid), private.guard_new_order(),
  private.lock_event_for_ticket() from public, anon, authenticated;

create or replace function public.validate_qr(p_token text, p_event_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_result public.scan_result;
  t public.tickets;
  v_status public.event_status;
  v_price numeric(10,2);
begin
  if v_uid is null or not private.has_door_role(p_event_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  select status into v_status from public.events where id = p_event_id for share;
  if v_status = 'draft' then
    insert into public.scan_logs (event_id, ticket_id, scanned_by, result)
    values (p_event_id, null, v_uid, 'event_inactive');
    return jsonb_build_object('result', 'event_inactive');
  end if;
  if not private.can_operate_door(p_event_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  if p_token is null or p_token !~ '^[0-9a-f]{64}$' then
    v_result := 'invalid';
  else
    select * into t from public.tickets
    where qr_token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex')
    for update;

    if not found then                    v_result := 'invalid';
    elsif t.event_id <> p_event_id then  v_result := 'wrong_event';
    elsif t.status = 'cancelled' then    v_result := 'cancelled';
    elsif t.status = 'used' then         v_result := 'already_used';
    elsif t.payment_status = 'pending' then v_result := 'pending_payment';
    else
      update public.tickets
         set status = 'used', checked_in_at = now(), checked_in_by = v_uid
       where id = t.id returning * into t;
      v_result := 'valid';
    end if;
  end if;

  insert into public.scan_logs (event_id, ticket_id, scanned_by, result)
  values (p_event_id, t.id, v_uid, v_result);

  if v_result = 'pending_payment' then
    select ticket_price into v_price from public.events where id = p_event_id;
    v_price := coalesce((to_jsonb(t) ->> 'unit_price')::numeric, v_price);  -- precio al emitir (migración 18)
  end if;

  -- invalid / wrong_event no filtran datos de ningún ticket
  return jsonb_build_object(
    'result', v_result,
    'ticket_id',      case when v_result not in ('invalid', 'wrong_event') then t.id end,
    'guest_name',     case when v_result not in ('invalid', 'wrong_event') then t.guest_name end,
    'payment_status', case when v_result not in ('invalid', 'wrong_event') then t.payment_status end,
    'amount_due',     case when v_result = 'pending_payment' then v_price end,
    'checked_in_at',  case when v_result in ('valid', 'already_used') then t.checked_in_at end
  );
end $$;

create or replace function public.confirm_checkin(p_ticket_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  t public.tickets;
  v_status public.event_status;
  v_result public.scan_result;
begin
  select * into t from public.tickets where id = p_ticket_id for update;
  if not found or v_uid is null or not private.has_door_role(t.event_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  select status into v_status from public.events where id = t.event_id for share;
  if v_status = 'draft' then
    raise exception 'event_inactive' using errcode = 'P0001';
  end if;
  if not private.can_operate_door(t.event_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  if t.status = 'cancelled' then
    v_result := 'cancelled';
  elsif t.status = 'used' then
    v_result := 'already_used';
  else
    v_result := case when t.payment_status = 'pending' then 'payment_collected' else 'manual_checkin' end;
    update public.tickets
       set payment_status = 'paid',
           payment_confirmed_at = coalesce(payment_confirmed_at, now()),
           payment_confirmed_by = coalesce(payment_confirmed_by, v_uid),
           status = 'used', checked_in_at = now(), checked_in_by = v_uid
     where id = t.id returning * into t;
  end if;

  insert into public.scan_logs (event_id, ticket_id, scanned_by, result)
  values (t.event_id, t.id, v_uid, v_result);

  return jsonb_build_object('result', v_result, 'ticket_id', t.id, 'guest_name', t.guest_name,
                            'checked_in_at', t.checked_in_at);
end $$;

-- El comprador ve el estado del evento (para avisarle que su QR aún no permite ingresar).
create or replace function public.get_order(p_order_id uuid, p_token text) returns jsonb
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

  select jsonb_agg(jsonb_build_object('type_id', t.id, 'type_name', t.name, 'qty', l.qty, 'unit_price', l.unit_price)
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
    'event', jsonb_build_object('id', e.id, 'name', e.name, 'starts_at', e.starts_at, 'status', e.status),
    'venue', jsonb_build_object('name', v.name, 'zone', v.zone),
    'bank', v_bank, 'lines', coalesce(v_lines, '[]'::jsonb), 'tickets', v_tickets);
end $$;
