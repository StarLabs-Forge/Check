-- 51 casos. Ejecutar SOLO en un proyecto de desarrollo (nunca en producción):
-- el resultado llega como excepción 'RESULTS: N PASS, M FAIL' y revierte todo.
-- Prueba: reglas de borrador, QR en borrador, inventario, precios, categorías, teléfono y expiración
-- (migraciones 14-20). Solo CHECK-DEV. Termina en excepción "RESULTS" y revierte todo.
do $t$
declare
  a uuid := gen_random_uuid(); e1 uuid; e2 uuid; e3 uuid; e4 uuid; gen uuid; vip uuid; x uuid;
  t2 uuid; t3 uuid; t4 uuid; o1 jsonb; o2 jsonb; o3 jsonb; o4 jsonb; o5 jsonb; m jsonb; qr text; msg text;
  c text := '{"sub":"%s","role":"authenticated"}';
  line text := 'jsonb_build_array(jsonb_build_object(''type_id'', %L::uuid, ''qty'', %s))';
begin
  create schema testkit;
  create table testkit.r (n serial, name text, ok boolean, got text);
  grant usage on schema testkit to anon, authenticated;
  grant insert, select on testkit.r to anon, authenticated;
  grant usage on sequence testkit.r_n_seq to anon, authenticated;
  create function testkit.t(p_name text, p_sql text, p_expect text) returns void language plpgsql as $f$
  declare v text; n bigint;
  begin
    begin
      if p_sql ~* '^\s*select' then execute p_sql into v; v := 'OK:' || coalesce(v, 'null');
      else execute p_sql; get diagnostics n = row_count; v := 'OK:' || n; end if;
    exception when others then v := sqlerrm; end;
    insert into testkit.r (name, ok, got) values (p_name, v like p_expect, left(v, 160));
  end $f$;

  insert into auth.users (id, aud, role, email, raw_app_meta_data, raw_user_meta_data)
  values (a, 'authenticated', 'authenticated', 'a@example.invalid', '{}', '{"full_name":"Admin A"}');
  update public.profiles set plan = 'pro' where id = a;

  perform set_config('request.jwt.claims', format(c, a), true);
  set local role authenticated;
  insert into public.venues (owner_id, name, bank_beneficiary, bank_account) values (a, 'Local A', 'Benef', '123');
  insert into public.events (owner_id, name, starts_at, ends_at, capacity, access_type, ticket_price)
  values (a, 'E1', now() + interval '1 day', now() + interval '2 days', 100, 'paid', 50) returning id into e1;
  select id into gen from public.ticket_types where event_id = e1;

  -- Cupos y aforo
  perform testkit.t('suma de cupos no supera aforo', format('insert into public.ticket_types (event_id,name,price,capacity) values (%L,''VIP'',120,10)', e1), 'category_capacity_exceeds_event');
  update public.ticket_types set capacity = 80 where id = gen;
  insert into public.ticket_types (event_id, name, price, capacity) values (e1, 'VIP', 120, 20) returning id into vip;
  perform testkit.t('no cabe una categoría más', format('insert into public.ticket_types (event_id,name,price,capacity) values (%L,''X'',1,1)', e1), 'category_capacity_exceeds_event');
  perform testkit.t('aforo no baja de la suma', format('update public.events set capacity = 90 where id = %L', e1), 'category_capacity_exceeds_event');
  perform public.set_event_status(e1, 'active');

  set local role anon;
  execute format('select public.create_order(%L,''Ana'',''1111111'',''+591 71111111'',null,' || line || ')', e1, gen, 3) into o1;
  execute format('select public.create_order(%L,''Ana'',''1111111'',''00591 7111-1111'',null,' || line || ')', e1, vip, 2) into o2;
  perform public.declare_payment((o1 ->> 'order_id')::uuid, o1 ->> 'token');
  execute format('select public.create_order(%L,''Ana'',''1111111'',''71111111'',null,' || line || ')', e1, gen, 1) into o3;
  perform testkit.t('4.º pedido, otro formato de teléfono', format('select public.create_order(%L,''Ana'',''222222'',''0 71111111'',null,' || line || ')', e1, gen, 1), 'too_many_open_orders');
  perform testkit.t('catálogo: categorías y precio', 'select (select jsonb_array_length(x->''types'') from jsonb_array_elements(public.public_events()) x where x->>''name''=''E1'')', 'OK:2');

  set local role authenticated;
  perform testkit.t('cupo bajo lo comprometido', format('update public.ticket_types set capacity = 3 where id = %L', gen), 'capacity_below_sold');
  perform testkit.t('cupo igual a lo comprometido', format('update public.ticket_types set capacity = 4 where id = %L', gen), 'OK:1');
  update public.ticket_types set capacity = 80 where id = gen;

  -- Emisión manual
  perform testkit.t('emisión sin categoría (firma antigua)', format('select public.create_ticket(p_event_id => %L, p_guest_name => ''Beto'', p_guest_phone => null, p_payment_status => ''paid'')', e1), 'ticket_type_required');
  perform testkit.t('emisión sin categoría (firma nueva)', format('select public.create_ticket(%L,''Beto'',null::uuid)', e1), 'ticket_type_required');
  m := public.create_ticket(e1, 'Beto', vip, null, 'paid');
  perform testkit.t('manual descuenta cupo', format('select (select (s->>''sold'')||''/''||(s->>''reserved'')||''/''||(s->>''available'') from jsonb_array_elements(public.ticket_type_stats(%L)) s where s->>''id''=%L)', e1, vip), 'OK:1/2/17');
  perform testkit.t('manual guarda precio al emitir', format('select unit_price::text from public.tickets where id = %L', m ->> 'ticket_id'), 'OK:120.00');
  perform testkit.t('emisión auditada', 'select count(*)::text from public.audit_log where action = ''ticket_issued''', 'OK:1');

  -- Precios históricos
  update public.ticket_types set price = 150 where id = vip;
  perform testkit.t('pedido anterior conserva precio', format('select unit_price::text from public.order_lines where order_id = %L', o2 ->> 'order_id'), 'OK:120.00');
  perform testkit.t('entrada anterior conserva precio', format('select unit_price::text from public.tickets where id = %L', m ->> 'ticket_id'), 'OK:120.00');
  perform testkit.t('cambio de precio auditado', format('select old_price::text||''>''||new_price::text from public.ticket_type_log where ticket_type_id = %L and action = ''updated''', vip), 'OK:120.00>150.00');
  perform testkit.t('precio negativo rechazado', format('update public.ticket_types set price = -1 where id = %L', vip), '%violates check constraint%');
  perform testkit.t('auditoría de categorías inmutable', 'delete from public.ticket_type_log', '%permission denied%');
  set local role anon;
  perform testkit.t('pedido nuevo usa precio nuevo (importe del servidor)', format('select public.create_order(%L,''Caro'',''333333'',''73333333'',null,' || line || ')->>''total''', e1, vip, 1), 'OK:150.00');

  -- Desactivación y eliminación
  set local role authenticated;
  update public.ticket_types set active = false where id = vip;
  perform testkit.t('inactiva conserva cupos comprometidos', format('select (select (s->>''reserved'') from jsonb_array_elements(public.ticket_type_stats(%L)) s where s->>''id''=%L)', e1, vip), 'OK:3');
  perform testkit.t('inactiva: sin emisión manual', format('select public.create_ticket(%L,''Dani'',%L::uuid)', e1, vip), 'invalid_ticket_type');
  perform testkit.t('eliminar con historial', format('delete from public.ticket_types where id = %L', vip), 'category_has_history');
  update public.ticket_types set capacity = 70 where id = gen;
  insert into public.ticket_types (event_id, name, price, capacity) values (e1, 'Nueva', 10, 1) returning id into x;
  m := public.create_ticket(e1, 'Eva', x);
  perform testkit.t('cupo agotado en emisión manual', format('select public.create_ticket(%L,''Fer'',%L::uuid)', e1, x), 'sold_out');
  perform testkit.t('eliminar categoría con entrada emitida', format('delete from public.ticket_types where id = %L', x), 'category_has_history');
  insert into public.ticket_types (event_id, name, price, capacity) values (e1, 'SinUso', 10, 1) returning id into x;
  perform testkit.t('eliminar sin historial', format('delete from public.ticket_types where id = %L', x), 'OK:1');
  perform testkit.t('baja auditada', format('select count(*)::text from public.ticket_type_log where ticket_type_id = %L and action = ''deleted''', x), 'OK:1');
  set local role anon;
  perform testkit.t('inactiva: sin compra', format('select public.create_order(%L,''Gil'',''444444'',''74444444'',null,' || line || ')', e1, vip, 1), 'invalid_ticket_type');
  set local role authenticated;
  perform public.declare_payment((o2 ->> 'order_id')::uuid, o2 ->> 'token');
  perform testkit.t('pago pendiente de categoría inactiva se puede aprobar', format('select public.decide_order(%L, true)->>''status''', o2 ->> 'order_id'), 'OK:approved');

  -- Borrador con reservas pendientes
  insert into public.events (owner_id, name, starts_at, ends_at, capacity, access_type, ticket_price)
  values (a, 'E2', now() + interval '1 day', now() + interval '2 days', 10, 'paid', 40) returning id into e2;
  select id into t2 from public.ticket_types where event_id = e2;
  perform public.set_event_status(e2, 'active');
  set local role anon;
  execute format('select public.create_order(%L,''Hugo'',''555555'',''75555555'',null,' || line || ')', e2, t2, 1) into o4;
  execute format('select public.create_order(%L,''Ines'',''666666'',''76666666'',null,' || line || ')', e2, t2, 1) into o5;
  set local role authenticated;
  perform testkit.t('borrador exige motivo', format('select public.set_event_status(%L, ''draft'')', e2), 'reason_required');
  perform testkit.t('borrador exige motivo (solo espacios)', format('select public.set_event_status(%L, ''draft'', ''   '')', e2), 'reason_required');
  perform testkit.t('UPDATE directo de estado bloqueado', format('update public.events set status = ''draft'' where id = %L', e2), '%permission denied%');
  perform testkit.t('borrador con reservas pendientes', format('select public.set_event_status(%L, ''draft'', ''Corregir horario'')->>''orders_pending''', e2), 'OK:2');
  perform testkit.t('auditoría del cambio', format('select old_status||''>''||new_status||''|''||reason||''|''||orders_pending||''|''||(actor_id = %L)::text from public.event_status_log where event_id = %L order by id desc limit 1', a, e2), 'OK:active>draft|Corregir horario|2|true');
  perform testkit.t('reserva conserva sus 15 minutos', format('select (expires_at - created_at)::text from public.orders where id = %L', o5 ->> 'order_id'), 'OK:00:15:00');
  set local role anon;
  perform testkit.t('sin pedidos nuevos en borrador', format('select public.create_order(%L,''Juan'',''777777'',''77777777'',null,' || line || ')', e2, t2, 1), 'event_not_available');
  perform testkit.t('catálogo oculta el borrador', 'select count(*)::text from jsonb_array_elements(public.public_events()) x where x->>''name''=''E2''', 'OK:0');
  perform testkit.t('informar pago en borrador', format('select public.declare_payment(%L,%L)->>''status''', o4 ->> 'order_id', o4 ->> 'token'), 'OK:verifying');
  set local role authenticated;
  perform testkit.t('aprobar en borrador', format('select public.decide_order(%L, true)->>''status''', o4 ->> 'order_id'), 'OK:approved');
  perform testkit.t('aprobar no reactiva el evento', format('select status::text from public.events where id = %L', e2), 'OK:draft');
  set local role anon;
  select public.get_order((o4 ->> 'order_id')::uuid, o4 ->> 'token') into m;
  qr := m -> 'tickets' -> 0 ->> 'qr_token';
  perform testkit.t('comprador ve QR y estado del evento', format('select %L', (m -> 'event' ->> 'status') || '|' || jsonb_array_length(m -> 'tickets')), 'OK:draft|1');
  set local role authenticated;
  perform testkit.t('QR en borrador no permite ingreso', format('select public.validate_qr(%L,%L)->>''result''', qr, e2), 'OK:event_inactive');
  perform testkit.t('QR no queda usado', format('select status::text from public.tickets where order_id = %L', o4 ->> 'order_id'), 'OK:issued');
  perform testkit.t('ingreso manual bloqueado en borrador', format('select public.confirm_checkin((select id from public.tickets where order_id = %L))', o4 ->> 'order_id'), 'event_inactive');
  perform public.set_event_status(e2, 'active');
  perform testkit.t('tras reactivar, QR válido', format('select public.validate_qr(%L,%L)->>''result''', qr, e2), 'OK:valid');
  perform testkit.t('segundo escaneo', format('select public.validate_qr(%L,%L)->>''result''', qr, e2), 'OK:already_used');
  perform testkit.t('borrador con QR usado', format('select public.set_event_status(%L, ''draft'', ''motivo'')', e2), 'draft_blocked_used_qr');

  perform testkit.t('borrador con venta aprobada', format('select public.set_event_status(%L, ''draft'', ''motivo'')', e1), 'draft_blocked_sales');
  insert into public.events (owner_id, name, starts_at, ends_at, capacity, access_type, ticket_price)
  values (a, 'E3', now() + interval '1 day', now() + interval '2 days', 10, 'paid', 40) returning id into e3;
  select id into t3 from public.ticket_types where event_id = e3;
  perform public.set_event_status(e3, 'active');
  perform public.create_ticket(e3, 'Kim', t3, null, 'pending');
  perform testkit.t('manual por cobrar no es venta', format('select public.set_event_status(%L, ''draft'', ''motivo'')->>''status''', e3), 'OK:draft');
  perform public.set_event_status(e3, 'active');
  perform public.create_ticket(e3, 'Lia', t3, null, 'paid');
  perform testkit.t('manual pagada impide borrador', format('select public.set_event_status(%L, ''draft'', ''motivo'')', e3), 'draft_blocked_sales');

  -- Expiración controlada por el servidor
  insert into public.events (owner_id, name, starts_at, ends_at, capacity, access_type, ticket_price)
  values (a, 'E4', now() + interval '1 day', now() + interval '2 days', 1, 'paid', 40) returning id into e4;
  select id into t4 from public.ticket_types where event_id = e4;
  perform public.set_event_status(e4, 'active');
  set local role anon;
  execute format('select public.create_order(%L,''Mar'',''888888'',''78888888'',null,' || line || ')', e4, t4, 1) into o1;
  perform testkit.t('último cupo retenido', format('select public.create_order(%L,''Nia'',''999999'',''79999999'',null,' || line || ')', e4, t4, 1), 'sold_out');
  reset role;
  update public.orders set expires_at = now() - interval '1 second' where id = (o1 ->> 'order_id')::uuid;
  set local role anon;
  perform testkit.t('pedido vencido no admite pago', format('select public.declare_payment(%L,%L)', o1 ->> 'order_id', o1 ->> 'token'), 'order_expired');
  perform testkit.t('el cupo se libera al vencer', format('select (public.create_order(%L,''Nia'',''999999'',''79999999'',null,' || line || ') ? ''order_id'')::text', e4, t4, 1), 'OK:true');

  reset role;
  select count(*) filter (where ok) || ' PASS, ' || count(*) filter (where not ok) || ' FAIL. ' ||
         coalesce(string_agg(name || ' => ' || got, ' ;; ' order by n) filter (where not ok), '') into msg from testkit.r;
  raise exception 'RESULTS: %', msg;
end $t$;
