-- Prueba de regresión de la migración 14. Ejecutar DESPUÉS de aplicarla, en un
-- entorno de desarrollo/rama de Supabase. Todo ocurre dentro de una transacción
-- que termina en ROLLBACK: el resultado llega como el mensaje de una excepción
-- "RESULTS: ...". Resultado esperado (resumen):
--   profile_role=admin (el rol NO sale del metadata del cliente)
--   trial_without_venue=venue_required; trial1 == trial2 (idempotente, 14 días)
--   trial_update=blocked; trial_insert=blocked
--   orders_3_ok; phone4=too_many_open_orders; other_phone_ok
--   inactive=invalid_ticket_type; draft_noreason=reason_required
--   log con 3 filas (motivo y pedidos pendientes); log_delete=blocked
begin;
do $t$
declare
  u uuid := gen_random_uuid(); ev uuid; t1 uuid; t2 uuid; o jsonb; out text := ''; r jsonb; n int;
begin
  insert into auth.users (id, aud, role, email, raw_app_meta_data, raw_user_meta_data)
  values (u, 'authenticated', 'authenticated', 'rollback-test@example.invalid', '{}',
          '{"full_name":"Test Rollback","role":"super_admin"}');
  out := out || format('profile_role=%s;', (select role from public.profiles where id = u));

  perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  set local role authenticated;
  begin perform public.start_trial(); exception when others then out := out || 'trial_without_venue=' || sqlerrm || ';'; end;
  insert into public.venues (owner_id, name, bank_beneficiary, bank_account) values (u, 'Local Test', 'Benef', '123');
  insert into public.events (owner_id, name, starts_at, ends_at, capacity, access_type, ticket_price)
  values (u, 'Evento Test', now() + interval '1 day', now() + interval '2 days', 100, 'paid', 50) returning id into ev;
  perform public.set_event_status(ev, 'active');
  select id into t1 from public.ticket_types where event_id = ev limit 1;
  insert into public.ticket_types (event_id, name, price, capacity, description)
  values (ev, 'VIP', 120, 10, 'Zona VIP') returning id into t2;

  out := out || 'trial1=' || public.start_trial()::text || ';';
  out := out || 'trial2=' || public.start_trial()::text || ';';
  begin update public.venue_trials set ends_at = ends_at + interval '30 days'; out := out || 'trial_update=ALLOWED(BAD);';
  exception when others then out := out || 'trial_update=blocked;'; end;
  begin insert into public.venue_trials (owner_id, ends_at) values (u, now()); out := out || 'trial_insert=ALLOWED(BAD);';
  exception when others then out := out || 'trial_insert=blocked;'; end;

  set local role anon;
  for n in 1..3 loop
    o := public.create_order(ev, 'Comprador ' || n, 'CI12345' || n,
           case n when 1 then '7 111 1111' when 2 then '71111111' else '711-11111' end, null,
           jsonb_build_array(jsonb_build_object('type_id', t1, 'qty', 1)));
  end loop;
  out := out || 'orders_3_ok;';
  begin perform public.create_order(ev, 'Otro', 'CI999999', '(7)111-1111', null,
          jsonb_build_array(jsonb_build_object('type_id', t1, 'qty', 1)));
        out := out || 'phone4=ALLOWED(BAD);';
  exception when others then out := out || 'phone4=' || sqlerrm || ';'; end;
  o := public.create_order(ev, 'Otro', 'CI999999', '72222222', null,
         jsonb_build_array(jsonb_build_object('type_id', t2, 'qty', 2), jsonb_build_object('type_id', t1, 'qty', 1)));
  out := out || 'mixed_order_total=' || (o ->> 'total') || ';other_phone_ok;';

  set local role authenticated;
  update public.ticket_types set active = false where id = t2;
  set local role anon;
  begin perform public.create_order(ev, 'Otro', 'CI999998', '73333333', null,
          jsonb_build_array(jsonb_build_object('type_id', t2, 'qty', 1)));
        out := out || 'inactive=ALLOWED(BAD);';
  exception when others then out := out || 'inactive=' || sqlerrm || ';'; end;
  out := out || 'public_types_after=' || jsonb_array_length(public.public_events() -> 0 -> 'types') || ';';

  set local role authenticated;
  begin perform public.set_event_status(ev, 'draft'); out := out || 'draft_noreason=ALLOWED(BAD);';
  exception when others then out := out || 'draft_noreason=' || sqlerrm || ';'; end;
  perform public.set_event_status(ev, 'draft', 'Corregir datos');
  perform public.set_event_status(ev, 'active');
  select jsonb_agg(jsonb_build_object('old', old_status, 'new', new_status, 'why', reason,
                                      'pending', orders_pending, 'actor_ok', actor_id = u) order by id)
    into r from public.event_status_log where event_id = ev;
  out := out || 'log=' || r::text || ';';
  begin delete from public.event_status_log; out := out || 'log_delete=ALLOWED(BAD);';
  exception when others then out := out || 'log_delete=blocked;'; end;

  reset role;
  raise exception 'RESULTS: %', out;
end $t$;
rollback;
