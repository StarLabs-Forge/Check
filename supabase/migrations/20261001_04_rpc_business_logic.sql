-- ============ STAFF ============
create function public.create_staff_invite(
  p_event_id uuid, p_display_name text, p_ttl_hours int default 48
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_status public.event_status;
  v_max int; v_count int; v_code text; v_id uuid; v_exp timestamptz;
begin
  if v_uid is null or not private.owns_event(p_event_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if coalesce(btrim(p_display_name), '') = '' or char_length(p_display_name) > 80 then
    raise exception 'invalid_display_name' using errcode = 'P0001';
  end if;
  if p_ttl_hours is null or p_ttl_hours not between 1 and 168 then
    raise exception 'invalid_ttl' using errcode = 'P0001';
  end if;

  select status into v_status from public.events where id = p_event_id;
  if v_status in ('finished', 'suspended') then
    raise exception 'event_closed' using errcode = 'P0001';
  end if;

  select pl.max_staff_per_event into v_max
  from public.profiles p join public.plan_limits pl on pl.plan = p.plan
  where p.id = v_uid;
  if v_max is not null then
    select count(*) into v_count from public.event_staff
    where event_id = p_event_id and revoked_at is null
      and (redeemed_at is not null or code_expires_at > now());
    if v_count >= v_max then
      raise exception 'plan_limit_staff' using errcode = 'P0001',
        hint = 'El plan permite ' || v_max || ' staff por evento.';
    end if;
  end if;

  v_code := private.gen_staff_code();
  v_exp  := now() + make_interval(hours => p_ttl_hours);
  insert into public.event_staff (event_id, display_name, code_hash, code_expires_at, created_by)
  values (p_event_id, btrim(p_display_name),
          encode(extensions.digest(v_code, 'sha256'), 'hex'), v_exp, v_uid)
  returning id into v_id;

  -- El código en claro se devuelve UNA sola vez; en BD solo queda el hash.
  return jsonb_build_object('staff_row_id', v_id, 'code', v_code, 'expires_at', v_exp);
end $$;

create function public.revoke_staff(p_staff_row_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_event uuid;
begin
  select event_id into v_event from public.event_staff where id = p_staff_row_id;
  if v_event is null or not private.owns_event(v_event) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  update public.event_staff set revoked_at = now()
  where id = p_staff_row_id and revoked_at is null;
end $$;

-- El staff entra con sesión anónima de Supabase + este código. No devuelve errores
-- por excepción para que el intento fallido quede registrado (throttle).
create function public.redeem_staff_code(p_code text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_hash text; v_role public.user_role; v_recent int; r public.event_staff;
begin
  if v_uid is null then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  select count(*) into v_recent from private.redeem_attempts
  where user_id = v_uid and attempted_at > now() - interval '15 minutes';
  if v_recent >= 10 then
    return jsonb_build_object('ok', false, 'error', 'too_many_attempts');
  end if;

  v_hash := encode(extensions.digest(
              upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g')), 'sha256'), 'hex');

  select es.* into r
  from public.event_staff es join public.events e on e.id = es.event_id
  where es.code_hash = v_hash
    and es.redeemed_at is null and es.revoked_at is null
    and es.code_expires_at > now()
    and e.status in ('draft', 'active', 'live')
  for update of es;

  if not found then
    insert into private.redeem_attempts (user_id) values (v_uid);
    return jsonb_build_object('ok', false, 'error', 'invalid_code');
  end if;

  -- Un admin/super_admin existente jamás puede degradarse a staff con un código
  select role into v_role from public.profiles where id = v_uid;
  if v_role is not null and v_role <> 'staff' then
    return jsonb_build_object('ok', false, 'error', 'account_not_staff');
  end if;

  insert into public.profiles (id, full_name, role)
  values (v_uid, r.display_name, 'staff')
  on conflict (id) do update set full_name = excluded.full_name;

  update public.event_staff set staff_id = v_uid, redeemed_at = now() where id = r.id;
  return jsonb_build_object('ok', true, 'event_id', r.event_id);
end $$;

-- ============ TICKETS ============
-- Devuelve el token QR en claro UNA sola vez (64 hex = 256 bits). En BD solo el hash.
create function public.create_ticket(
  p_event_id uuid, p_guest_name text, p_guest_phone text default null,
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

  select * into e from public.events where id = p_event_id;
  if e.status in ('finished', 'suspended') then
    raise exception 'event_closed' using errcode = 'P0001';
  end if;

  -- Serializa el control de cuota por admin (evita carrera entre dos altas simultáneas)
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

  -- Evento gratis: no hay nada que cobrar => nace pagado (nunca sale amarillo)
  v_pay := case when e.access_type = 'free' then 'paid' else p_payment_status end;
  v_token := encode(extensions.gen_random_bytes(32), 'hex');

  insert into public.tickets (event_id, guest_name, guest_phone, qr_token_hash, payment_status,
                              payment_confirmed_at, payment_confirmed_by, created_by)
  values (p_event_id, btrim(p_guest_name), nullif(btrim(p_guest_phone), ''),
          encode(extensions.digest(v_token, 'sha256'), 'hex'), v_pay,
          case when v_pay = 'paid' then now() end,
          case when v_pay = 'paid' then v_uid end, v_uid)
  returning id into v_id;

  return jsonb_build_object('ticket_id', v_id, 'qr_token', v_token, 'payment_status', v_pay);
end $$;

create function public.mark_ticket_paid(p_ticket_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_event uuid;
begin
  select event_id into v_event from public.tickets where id = p_ticket_id;
  if v_event is null or not private.owns_event(v_event) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  update public.tickets
     set payment_status = 'paid', payment_confirmed_at = now(), payment_confirmed_by = auth.uid()
   where id = p_ticket_id and status = 'issued' and payment_status = 'pending';
  if not found then
    raise exception 'ticket_not_payable' using errcode = 'P0001';
  end if;
end $$;

create function public.cancel_ticket(p_ticket_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_event uuid;
begin
  select event_id into v_event from public.tickets where id = p_ticket_id;
  if v_event is null or not private.owns_event(v_event) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  update public.tickets set status = 'cancelled'
   where id = p_ticket_id and status = 'issued';
  if not found then
    raise exception 'ticket_not_cancellable' using errcode = 'P0001';
  end if;
end $$;

-- ============ PUERTA ============
-- Escaneo: valida y, si está pagado, registra el ingreso en la MISMA transacción
-- (verde = ya quedó adentro). SELECT ... FOR UPDATE evita doble ingreso por carrera.
create function public.validate_qr(p_token text, p_event_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_result public.scan_result;
  t public.tickets;
  v_price numeric(10,2);
begin
  if v_uid is null or not private.can_operate_door(p_event_id) then
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

-- Cobro en puerta (amarillo) y/o ingreso manual (búsqueda por nombre, sin QR)
create function public.confirm_checkin(p_ticket_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  t public.tickets;
  v_result public.scan_result;
begin
  select * into t from public.tickets where id = p_ticket_id for update;
  if not found or v_uid is null or not private.can_operate_door(t.event_id) then
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

-- Búsqueda manual para el staff: nunca expone token ni teléfono completo
create function public.search_tickets(p_event_id uuid, p_query text, p_limit int default 20)
returns table (ticket_id uuid, guest_name text, phone_last4 text,
               payment_status public.payment_status, status public.ticket_status)
language plpgsql stable security definer set search_path = '' as $$
declare v_q text;
begin
  if auth.uid() is null or not private.can_operate_door(p_event_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  v_q := btrim(coalesce(p_query, ''));
  if char_length(v_q) < 2 then
    raise exception 'query_too_short' using errcode = 'P0001';
  end if;
  v_q := replace(replace(replace(v_q, '\', '\\'), '%', '\%'), '_', '\_');

  return query
    select t.id, t.guest_name, right(regexp_replace(coalesce(t.guest_phone, ''), '\D', '', 'g'), 4),
           t.payment_status, t.status
    from public.tickets t
    where t.event_id = p_event_id and t.guest_name ilike '%' || v_q || '%'
    order by t.guest_name
    limit least(greatest(coalesce(p_limit, 20), 1), 50);
end $$;

-- ===== Permisos de ejecución: solo usuarios autenticados, nunca anon =====
revoke all on function public.create_staff_invite(uuid, text, int)              from public, anon;
revoke all on function public.revoke_staff(uuid)                                from public, anon;
revoke all on function public.redeem_staff_code(text)                           from public, anon;
revoke all on function public.create_ticket(uuid, text, text, public.payment_status) from public, anon;
revoke all on function public.mark_ticket_paid(uuid)                            from public, anon;
revoke all on function public.cancel_ticket(uuid)                               from public, anon;
revoke all on function public.validate_qr(text, uuid)                           from public, anon;
revoke all on function public.confirm_checkin(uuid)                             from public, anon;
revoke all on function public.search_tickets(uuid, text, int)                   from public, anon;

grant execute on function public.create_staff_invite(uuid, text, int)              to authenticated;
grant execute on function public.revoke_staff(uuid)                                to authenticated;
grant execute on function public.redeem_staff_code(text)                           to authenticated;
grant execute on function public.create_ticket(uuid, text, text, public.payment_status) to authenticated;
grant execute on function public.mark_ticket_paid(uuid)                            to authenticated;
grant execute on function public.cancel_ticket(uuid)                               to authenticated;
grant execute on function public.validate_qr(text, uuid)                           to authenticated;
grant execute on function public.confirm_checkin(uuid)                             to authenticated;
grant execute on function public.search_tickets(uuid, text, int)                   to authenticated;
