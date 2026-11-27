-- 55 casos. Ejecutar SOLO en un proyecto de desarrollo (nunca en producción):
-- el resultado llega como excepción 'RESULTS: N PASS, M FAIL' y revierte todo.
-- Prueba: MFA (aal2) exigido en el servidor, recuperación auditada y aislamiento entre
-- locales (migraciones 20 y 22). Solo CHECK-DEV. Los claims JWT se simulan; todo se revierte.
do $t$
declare
  a uuid := gen_random_uuid(); b uuid := gen_random_uuid(); s uuid := gen_random_uuid(); st uuid := gen_random_uuid();
  e1 uuid; t1 uuid; o1 jsonb; msg text; ts bigint := extract(epoch from now())::bigint - 60;
  aal1 text := '{"sub":"%s","role":"authenticated","aal":"aal1"}';
  aal2 text := '{"sub":"%s","role":"authenticated","aal":"aal2","amr":[{"method":"password","timestamp":%s},{"method":"totp","timestamp":%s}]}';
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

  insert into auth.users (id, aud, role, email, raw_app_meta_data, raw_user_meta_data) values
    (a, 'authenticated', 'authenticated', 'a@example.invalid', '{}', '{"role":"super_admin"}'),
    (b, 'authenticated', 'authenticated', 'b@example.invalid', '{}', '{}'),
    (s, 'authenticated', 'authenticated', 's@example.invalid', '{}', '{}'),
    (st, 'authenticated', 'authenticated', 'st@example.invalid', '{}', '{}');
  update public.profiles set role = 'super_admin' where id = s;
  update public.profiles set role = 'staff' where id = st;
  insert into public.venues (owner_id, name, bank_beneficiary, bank_account) values (a, 'Local A', 'Benef', '123'), (b, 'Local B', 'Benef', '456');
  insert into public.events (owner_id, name, starts_at, ends_at, capacity, access_type, ticket_price, status)
  values (a, 'E1', now() + interval '1 day', now() + interval '2 days', 10, 'paid', 50, 'draft') returning id into e1;
  select id into t1 from public.ticket_types where event_id = e1;
  update public.events set status = 'active' where id = e1;
  insert into public.staff_accounts (staff_id, owner_id, permissions) values (st, a, '{scanQr}');
  insert into public.event_staff (event_id, staff_id, display_name, code_hash, code_expires_at, redeemed_at, created_by)
  values (e1, st, 'Puerta', 'x:' || st, now(), now(), a);
  set local role anon;
  o1 := public.create_order(e1, 'Ana', '111111', '71111111', null, jsonb_build_array(jsonb_build_object('type_id', t1, 'qty', 1)));
  perform public.declare_payment((o1 ->> 'order_id')::uuid, o1 ->> 'token');

  -- Aislamiento, roles y RPC (interruptor MFA apagado)
  perform testkit.t('anon no lee tablas', 'select count(*)::text from public.orders', '%permission denied%');
  perform testkit.t('anon no ejecuta RPC de admin', format('select public.set_event_status(%L, ''finished'')', e1), '%permission denied%');
  perform set_config('request.jwt.claims', format(aal1, a), true);
  set local role authenticated;
  perform testkit.t('metadata no otorga rol', format('select role::text from public.profiles where id = %L', a), 'OK:admin');
  perform testkit.t('no puede cambiar su rol', format('update public.profiles set role = ''super_admin'' where id = %L', a), '%permission denied%');
  perform testkit.t('no puede cambiar su plan', format('update public.profiles set plan = ''premium'' where id = %L', a), '%permission denied%');
  perform testkit.t('no escribe pedidos', 'update public.orders set total = 1', '%permission denied%');
  perform testkit.t('no escribe auditoría', 'delete from public.event_status_log', '%permission denied%');
  perform testkit.t('sin MFA obligatorio: admin opera', 'select count(*)::text from public.venues', 'OK:1');
  perform set_config('request.jwt.claims', format(aal1, b), true);
  perform testkit.t('B no ve eventos de A', 'select count(*)::text from public.events', 'OK:0');
  perform testkit.t('B no ve pedidos de A', 'select count(*)::text from public.orders', 'OK:0');
  perform testkit.t('B no ve categorías de A', 'select count(*)::text from public.ticket_types', 'OK:0');
  perform testkit.t('B no ve auditoría de A', 'select count(*)::text from public.ticket_type_log', 'OK:0');
  perform testkit.t('B no cambia estado de A', format('select public.set_event_status(%L, ''finished'')', e1), 'forbidden');
  perform testkit.t('B no edita categoría de A', format('update public.ticket_types set price = 1 where id = %L', t1), 'OK:0');
  perform testkit.t('B no crea categoría en A', format('insert into public.ticket_types (event_id,name,price,capacity) values (%L,''x'',1,1)', e1), '%');
  perform testkit.t('B no aprueba pago de A', format('select public.decide_order(%L, true)', o1 ->> 'order_id'), 'forbidden');
  perform testkit.t('B no emite en evento de A', format('select public.create_ticket(%L,''x'',%L::uuid)', e1, t1), 'forbidden');
  perform testkit.t('B no ve cifras de A', format('select public.ticket_type_stats(%L)::text', e1), 'OK:[]');
  perform testkit.t('B no usa panel superadmin', 'select public.superadmin_commercial_overview()', 'forbidden');
  reset role;
  perform testkit.t('categoría ajena no se creó', format('select count(*)::text from public.ticket_types where event_id = %L', e1), 'OK:1');

  -- MFA obligatorio
  update public.platform_settings set mfa_required = true where id;
  perform set_config('request.jwt.claims', format(aal1, a), true);
  set local role authenticated;
  perform testkit.t('aal1: lee su perfil', 'select count(*)::text from public.profiles', 'OK:1');
  perform testkit.t('aal1: estado MFA', 'select (j->>''required'')||''|''||(j->>''satisfied'')||''|''||(j->>''enrolled'') from public.session_mfa_status() j', 'OK:true|false|false');
  perform testkit.t('aal1: sin local', 'select count(*)::text from public.venues', 'OK:0');
  perform testkit.t('aal1: sin eventos', 'select count(*)::text from public.events', 'OK:0');
  perform testkit.t('aal1: sin pedidos', 'select count(*)::text from public.orders', 'OK:0');
  perform testkit.t('aal1: sin vistas con cifras', 'select count(*)::text from public.events_with_stats', 'OK:0');
  perform testkit.t('aal1: sin auditoría', 'select count(*)::text from public.audit_log', 'OK:0');
  perform testkit.t('aal1: sin gestionar eventos', format('select public.set_event_status(%L, ''finished'')', e1), 'forbidden');
  perform testkit.t('aal1: sin crear eventos', format('insert into public.events (owner_id,name,starts_at,ends_at,capacity) values (%L,''z'',now()+interval ''1 day'',now()+interval ''2 days'',1)', a), '%row-level security%');
  perform testkit.t('aal1: sin aprobar pagos', format('select public.decide_order(%L, true)', o1 ->> 'order_id'), 'forbidden');
  perform testkit.t('aal1: sin emitir', format('select public.create_ticket(%L,''x'',%L::uuid)', e1, t1), 'forbidden');
  perform testkit.t('aal1: sin personal', 'select count(*)::text from public.staff_accounts', 'OK:0');
  perform testkit.t('aal1: sin permisos de personal', format('select public.staff_update(%L, ''x'', null, null)', st), 'forbidden');
  perform testkit.t('aal1: sin verificadores', format('select public.grant_payment_verifier(%L)', st), 'forbidden');
  perform testkit.t('aal1: sin prueba gratuita', 'select public.start_trial()', 'forbidden');
  perform testkit.t('aal1: sin editar perfil', format('update public.profiles set full_name = ''z'' where id = %L', a), 'OK:0');

  perform set_config('request.jwt.claims', format(aal2, a, ts, ts), true);
  perform testkit.t('aal2 sin factor registrado: denegado', 'select count(*)::text from public.events', 'OK:0');
  reset role;
  insert into auth.mfa_factors (id, user_id, friendly_name, factor_type, status, created_at, updated_at, secret) values
    (gen_random_uuid(), a, 't', 'totp', 'verified', now(), now(), 'test'),
    (gen_random_uuid(), s, 't', 'totp', 'verified', now(), now(), 'test');
  set local role authenticated;
  perform testkit.t('aal2 + factor: ve su local', 'select count(*)::text from public.venues', 'OK:1');
  perform testkit.t('aal2 + factor: aprueba pago', format('select public.decide_order(%L, true)->>''status''', o1 ->> 'order_id'), 'OK:approved');
  perform set_config('request.jwt.claims', format(aal1, a), true);
  perform testkit.t('con factor pero sesión aal1: denegado', 'select count(*)::text from public.venues', 'OK:0');

  perform set_config('request.jwt.claims', format(aal1, st), true);
  perform testkit.t('staff no requiere MFA', format('select public.validate_qr(''no'', %L)->>''result''', e1), 'OK:invalid');

  perform set_config('request.jwt.claims', format(aal1, s), true);
  perform testkit.t('superadmin aal1: sin panel', 'select public.superadmin_users()', 'forbidden');
  perform testkit.t('superadmin aal1: sin ajustes', 'select count(*)::text from public.platform_settings', 'OK:0');
  perform testkit.t('superadmin aal1: no restablece MFA', format('select public.superadmin_authorize_mfa_reset(%L, ''identidad verificada'')', a), 'forbidden');

  -- Recuperación
  perform set_config('request.jwt.claims', format(aal2, s, ts, ts), true);
  perform testkit.t('superadmin aal2: panel', 'select (public.superadmin_commercial_overview() is not null)::text', 'OK:true');
  perform testkit.t('restablecer exige motivo', format('select public.superadmin_authorize_mfa_reset(%L, ''corto'')', a), 'reason_required');
  perform testkit.t('no restablece a superadmin', format('select public.superadmin_authorize_mfa_reset(%L, ''identidad verificada'')', s), 'target_not_admin');
  perform testkit.t('restablecimiento autorizado', format('select public.superadmin_authorize_mfa_reset(%L, ''Identidad verificada por videollamada'')->>''result''', a), 'OK:ok');
  perform testkit.t('restablecimiento auditado', 'select count(*)::text from public.platform_log where action = ''mfa_reset''', 'OK:1');
  perform testkit.t('registro de restablecimiento inmutable', 'delete from public.mfa_resets', '%permission denied%');
  perform set_config('request.jwt.claims', format(aal2, a, ts, ts), true);
  perform testkit.t('token anterior al restablecimiento: denegado', 'select count(*)::text from public.venues', 'OK:0');
  perform testkit.t('admin no autoriza restablecimientos', format('select public.superadmin_authorize_mfa_reset(%L, ''identidad verificada'')', b), 'forbidden');
  perform set_config('request.jwt.claims', format(aal2, a, ts, ts + 120), true);
  perform testkit.t('nuevo TOTP posterior: acceso', 'select count(*)::text from public.venues', 'OK:1');
  reset role;
  delete from auth.mfa_factors where user_id = a;
  set local role authenticated;
  perform testkit.t('factor eliminado: denegado aunque el token sea aal2', 'select count(*)::text from public.venues', 'OK:0');
  reset role;
  perform testkit.t('toda tabla con RLS tiene política restrictiva MFA',
    'select string_agg(c.relname, '','') from pg_class c where c.relnamespace = ''public''::regnamespace and c.relkind = ''r'' and (not c.relrowsecurity or not exists (select 1 from pg_policies p where p.schemaname = ''public'' and p.tablename = c.relname and p.permissive = ''RESTRICTIVE''))', 'OK:null');

  select count(*) filter (where ok) || ' PASS, ' || count(*) filter (where not ok) || ' FAIL. ' ||
         coalesce(string_agg(name || ' => ' || got, ' ;; ' order by n) filter (where not ok), '') into msg from testkit.r;
  raise exception 'RESULTS: %', msg;
end $t$;
