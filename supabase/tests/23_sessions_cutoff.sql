-- 11 casos. Ejecutar SOLO en un proyecto de desarrollo: el resultado llega como
-- excepción 'RESULTS: N PASS, M FAIL' y revierte todo.
-- Prueba: revocación de sesiones (21) y aviso de corte de las 10:00 (23).
-- Solo CHECK-DEV. Termina en excepción "RESULTS" y revierte todo.
do $t$
declare
  a uuid := gen_random_uuid(); b uuid := gen_random_uuid(); s uuid := gen_random_uuid();
  hoy uuid; futuro uuid; t1 uuid; t2 uuid; o1 jsonb; o2 jsonb; o3 jsonb; msg text;
  c text := '{"sub":"%s","role":"authenticated"}';
  line text := 'jsonb_build_array(jsonb_build_object(''type_id'', %L::uuid, ''qty'', 1))';
  ayer timestamptz;
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
    insert into testkit.r (name, ok, got) values (p_name, v like p_expect, left(v, 200));
  end $f$;

  insert into auth.users (id, aud, role, email, raw_app_meta_data, raw_user_meta_data) values
    (a, 'authenticated', 'authenticated', 'a@example.invalid', '{}', '{}'),
    (b, 'authenticated', 'authenticated', 'b@example.invalid', '{}', '{}'),
    (s, 'authenticated', 'authenticated', 's@example.invalid', '{}', '{}');
  update public.profiles set role = 'super_admin' where id = s;
  insert into auth.sessions (id, user_id, created_at, updated_at) values
    (gen_random_uuid(), a, now(), now()), (gen_random_uuid(), a, now(), now()), (gen_random_uuid(), b, now(), now());

  insert into public.venues (owner_id, name, bank_beneficiary, bank_account) values (a, 'Local A', 'Benef', '123'), (b, 'Local B', 'Benef', '456');
  -- Un evento cuyo corte ya pasó (día anterior en hora de Bolivia, aún sin terminar) y otro futuro.
  ayer := (date_trunc('day', now() at time zone 'America/La_Paz') - interval '1 day' + interval '22 hours') at time zone 'America/La_Paz';
  insert into public.events (owner_id, name, starts_at, ends_at, capacity, access_type, ticket_price)
  values (a, 'Corte pasado', ayer, now() + interval '1 day', 10, 'paid', 10) returning id into hoy;
  insert into public.events (owner_id, name, starts_at, ends_at, capacity, access_type, ticket_price)
  values (a, 'Futuro', now() + interval '5 days', now() + interval '6 days', 10, 'paid', 10) returning id into futuro;
  update public.events set status = 'active' where id in (hoy, futuro);
  select id into t1 from public.ticket_types where event_id = hoy;
  select id into t2 from public.ticket_types where event_id = futuro;

  set local role anon;
  execute format('select public.create_order(%L,''Ana'',''111111'',''71111111'',null,' || line || ')', hoy, t1) into o1;
  execute format('select public.create_order(%L,''Beto'',''222222'',''72222222'',null,' || line || ')', hoy, t1) into o2;
  execute format('select public.create_order(%L,''Caro'',''333333'',''73333333'',null,' || line || ')', futuro, t2) into o3;
  perform public.declare_payment((o1 ->> 'order_id')::uuid, o1 ->> 'token');
  perform public.declare_payment((o3 ->> 'order_id')::uuid, o3 ->> 'token');
  perform testkit.t('anónimo no consulta avisos', 'select public.payment_cutoff_alerts()', '%permission denied%');

  perform set_config('request.jwt.claims', format(c, a), true);
  set local role authenticated;
  perform testkit.t('avisa solo el pago informado de un corte pasado',
    'select string_agg((x->>''event_name'') || '':'' || (x->>''pending''), '','') from jsonb_array_elements(public.payment_cutoff_alerts()) x', 'OK:Corte pasado:1');
  perform testkit.t('corte a las 10:00 de Bolivia',
    'select to_char((public.payment_cutoff_alerts()->0->>''cutoff_at'')::timestamptz at time zone ''America/La_Paz'', ''HH24:MI'')', 'OK:10:00');
  perform testkit.t('no anula ni libera: sigue en verificación', format('select status::text from public.orders where id = %L', o1 ->> 'order_id'), 'OK:verifying');
  perform testkit.t('se puede aprobar después del corte', format('select public.decide_order(%L, true)->>''status''', o1 ->> 'order_id'), 'OK:approved');
  perform testkit.t('resuelto: el aviso desaparece', 'select public.payment_cutoff_alerts()::text', 'OK:[]');
  perform testkit.t('admin no restablece MFA (sesiones intactas)', format('select public.superadmin_authorize_mfa_reset(%L, ''identidad verificada'')', b), 'forbidden');

  perform set_config('request.jwt.claims', format(c, b), true);
  perform testkit.t('otro local no ve avisos ajenos', 'select public.payment_cutoff_alerts()::text', 'OK:[]');

  perform set_config('request.jwt.claims', format(c, s), true);
  perform testkit.t('restablecer MFA', format('select public.superadmin_authorize_mfa_reset(%L, ''Identidad verificada en persona'')->>''result''', a), 'OK:ok');
  reset role;
  perform testkit.t('cierra las sesiones del afectado', format('select count(*)::text from auth.sessions where user_id = %L', a), 'OK:0');
  perform testkit.t('no cierra sesiones de otros', format('select count(*)::text from auth.sessions where user_id = %L', b), 'OK:1');

  select count(*) filter (where ok) || ' PASS, ' || count(*) filter (where not ok) || ' FAIL. ' ||
         coalesce(string_agg(name || ' => ' || got, ' ;; ' order by n) filter (where not ok), '') into msg from testkit.r;
  raise exception 'RESULTS: %', msg;
end $t$;
