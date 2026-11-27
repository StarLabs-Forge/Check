-- 48 casos. Ejecutar SOLO en un proyecto de desarrollo (nunca en producción):
-- el resultado llega como excepción 'RESULTS: N PASS, M FAIL' y revierte todo.
-- Prueba: prueba de 14 días, restricciones comerciales, planes y avisos (migración 19).
-- Solo CHECK-DEV. Las fechas se adelantan dentro de la transacción; todo se revierte.
do $t$
declare
  a uuid := gen_random_uuid(); b uuid := gen_random_uuid(); s uuid := gen_random_uuid();
  ven uuid; e1 uuid; e2 uuid; t1 uuid; o1 jsonb; o2 jsonb; r1 jsonb; qr text; msg text; m jsonb;
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

  insert into auth.users (id, aud, role, email, raw_app_meta_data, raw_user_meta_data) values
    (a, 'authenticated', 'authenticated', 'a@example.invalid', '{}', '{}'),
    (b, 'authenticated', 'authenticated', 'b@example.invalid', '{}', '{}'),
    (s, 'authenticated', 'authenticated', 's@example.invalid', '{}', '{}');
  update public.profiles set role = 'super_admin' where id = s;
  update public.platform_settings set commercial_gate = true where id;

  -- Antes de activar
  perform set_config('request.jwt.claims', format(c, a), true);
  set local role authenticated;
  perform testkit.t('sin local no hay prueba', 'select public.start_trial()', 'venue_required');
  insert into public.venues (owner_id, name, bank_beneficiary, bank_account) values (a, 'Local A', 'Benef', '123') returning id into ven;
  perform testkit.t('registrarse no inicia la prueba', 'select count(*)::text from public.venue_trials', 'OK:0');
  insert into public.events (owner_id, name, starts_at, ends_at, capacity, access_type, ticket_price)
  values (a, 'E1', now() + interval '1 day', now() + interval '2 days', 20, 'paid', 50) returning id into e1;
  select id into t1 from public.ticket_types where event_id = e1;
  perform testkit.t('previo: configurar categorías', format('update public.ticket_types set name = ''Gral'', price = 60 where id = %L', t1), 'OK:1');
  perform testkit.t('previo: publicar bloqueado', format('select public.set_event_status(%L, ''active'')', e1), 'commercial_inactive');
  perform testkit.t('previo: emitir entrada bloqueado', format('select public.create_ticket(%L,''X'',%L::uuid)', e1, t1), 'commercial_inactive');
  set local role anon;
  perform testkit.t('previo: catálogo vacío', 'select jsonb_array_length(public.public_events())::text', 'OK:0');
  perform testkit.t('anon no puede activar', 'select public.start_trial()', '%permission denied%');

  -- Activación manual
  set local role authenticated;
  r1 := public.start_trial();
  perform testkit.t('activa 14 días', format('select (ends_at - started_at = interval ''14 days'')::text from public.venue_trials where venue_id = %L', ven), 'OK:true');
  perform testkit.t('estado inicial', format('select %L', (r1 ->> 'state') || '|' || (r1 ->> 'days_left')), 'OK:active|14');
  perform testkit.t('idempotente (no reinicia)', format('select (public.start_trial() ->> ''started_at'' = %L)::text', r1 ->> 'started_at'), 'OK:true');
  perform testkit.t('activación auditada una vez', 'select count(*)::text from public.venue_commercial_log where action = ''trial_activated''', 'OK:1');
  perform testkit.t('cliente no modifica fechas', 'update public.venue_trials set ends_at = ends_at + interval ''30 days''', '%permission denied%');
  perform testkit.t('cliente no inserta planes', format('insert into public.venue_subscriptions (venue_id, plan, payment_note, activated_by) values (%L, ''pro'', ''pagado'', %L)', ven, a), '%permission denied%');
  perform testkit.t('cliente no apaga el interruptor', 'update public.platform_settings set commercial_gate = false', '%permission denied%');
  perform testkit.t('admin no asigna planes', format('select public.superadmin_assign_plan(%L, ''pro'', ''pagado'')', a), 'forbidden');
  reset role;
  update public.venues set owner_id = b where id = ven;
  perform set_config('request.jwt.claims', format(c, b), true);
  set local role authenticated;
  perform testkit.t('cambiar de administrador no reinicia', format('select (public.start_trial() ->> ''started_at'' = %L)::text', r1 ->> 'started_at'), 'OK:true');
  reset role;
  update public.venues set owner_id = a where id = ven;

  -- Durante la prueba
  perform set_config('request.jwt.claims', format(c, a), true);
  set local role authenticated;
  perform testkit.t('publicar con prueba vigente', format('select public.set_event_status(%L, ''active'')->>''status''', e1), 'OK:active');
  set local role anon;
  execute format('select public.create_order(%L,''Ana'',''111111'',''71111111'',null,' || line || ')', e1, t1, 1) into o1;
  execute format('select public.create_order(%L,''Beto'',''222222'',''72222222'',null,' || line || ')', e1, t1, 1) into o2;
  perform public.declare_payment((o1 ->> 'order_id')::uuid, o1 ->> 'token');
  set local role authenticated;
  insert into public.events (owner_id, name, starts_at, ends_at, capacity, access_type, ticket_price)
  values (a, 'E2', now() + interval '3 days', now() + interval '4 days', 20, 'paid', 50) returning id into e2;

  -- Avisos: 2 días antes del fin
  reset role;
  alter table public.venue_trials disable trigger venue_trials_immutable;
  update public.venue_trials set started_at = date_trunc('milliseconds', now()) - interval '12 days',
         ends_at = date_trunc('milliseconds', now()) - interval '12 days' + interval '14 days' where venue_id = ven;
  alter table public.venue_trials enable trigger venue_trials_immutable;
  perform private.enqueue_trial_notifications();
  perform private.enqueue_trial_notifications();
  perform testkit.t('avisos sin duplicados; atrasados omitidos', 'select string_agg(kind || ''='' || email_status, '','' order by due_at) from public.trial_notifications', 'OK:d7=skipped,d3=pending');
  set local role authenticated;
  perform testkit.t('panel: por vencer', 'select (public.trial_status()->>''state'') || ''|'' || (public.trial_status()->>''days_left'')', 'OK:expiring|2');

  -- Vencida
  reset role;
  alter table public.venue_trials disable trigger venue_trials_immutable;
  update public.venue_trials set started_at = date_trunc('milliseconds', now()) - interval '15 days',
         ends_at = date_trunc('milliseconds', now()) - interval '1 day' where venue_id = ven;
  alter table public.venue_trials enable trigger venue_trials_immutable;
  set local role authenticated;
  perform testkit.t('panel: vencida', 'select public.trial_status()->>''state''', 'OK:expired');
  perform testkit.t('vencida: no se reactiva', 'select public.start_trial()->>''state''', 'OK:expired');
  perform testkit.t('vencida: crear borrador', format('insert into public.events (owner_id, name, starts_at, ends_at, capacity, access_type, ticket_price) values (%L, ''E3'', now() + interval ''5 days'', now() + interval ''6 days'', 5, ''paid'', 10)', a), 'OK:1');
  perform testkit.t('vencida: publicar bloqueado', format('select public.set_event_status(%L, ''active'')', e2), 'commercial_inactive');
  perform testkit.t('vencida: emisión manual bloqueada', format('select public.create_ticket(%L,''X'',%L::uuid)', e1, t1), 'commercial_inactive');
  set local role anon;
  perform testkit.t('vencida: sin reservas nuevas', format('select public.create_order(%L,''Caro'',''333333'',''73333333'',null,' || line || ')', e1, t1, 1), 'event_not_available');
  perform testkit.t('vencida: fuera del catálogo', 'select jsonb_array_length(public.public_events())::text', 'OK:0');
  perform testkit.t('vencida: reserva previa informa pago', format('select public.declare_payment(%L,%L)->>''status''', o2 ->> 'order_id', o2 ->> 'token'), 'OK:verifying');
  perform testkit.t('vencida: comprador consulta su pedido', format('select public.get_order(%L,%L)->''order''->>''status''', o1 ->> 'order_id', o1 ->> 'token'), 'OK:verifying');
  set local role authenticated;
  perform testkit.t('vencida: consultar ventas', 'select count(*)::text from public.orders', 'OK:2');
  perform testkit.t('vencida: aprobar pago pendiente', format('select public.decide_order(%L, true)->>''status''', o1 ->> 'order_id'), 'OK:approved');
  perform testkit.t('vencida: rechazar pago pendiente', format('select public.decide_order(%L, false, ''sin depósito'')->>''status''', o2 ->> 'order_id'), 'OK:rejected');
  set local role anon;
  qr := public.get_order((o1 ->> 'order_id')::uuid, o1 ->> 'token') -> 'tickets' -> 0 ->> 'qr_token';
  set local role authenticated;
  perform testkit.t('vencida: iniciar evento existente', format('select public.set_event_status(%L, ''live'')->>''status''', e1), 'OK:live');
  perform testkit.t('vencida: validar QR emitido', format('select public.validate_qr(%L,%L)->>''result''', qr, e1), 'OK:valid');
  perform testkit.t('vencida: finalizar evento', format('select public.set_event_status(%L, ''finished'')->>''status''', e1), 'OK:finished');

  -- Plan contratado
  perform set_config('request.jwt.claims', format(c, s), true);
  perform testkit.t('plan exige confirmación de pago', format('select public.superadmin_assign_plan(%L, ''pro'', '' '')', a), 'payment_note_required');
  perform testkit.t('asignar prueba ya usada', format('select public.superadmin_assign_trial(%L)', a), 'trial_already_used');
  perform testkit.t('activar plan', format('select public.superadmin_assign_plan(%L, ''pro'', ''Depósito verificado #123'')->>''result''', a), 'OK:ok');
  perform testkit.t('plan registrado con responsable', format('select (activated_by = %L)::text from public.venue_subscriptions where ended_at is null', s), 'OK:true');
  reset role;
  perform private.enqueue_trial_notifications();
  perform testkit.t('con plan se cancelan avisos pendientes', 'select count(*)::text from public.trial_notifications where email_status = ''pending''', 'OK:0');
  perform set_config('request.jwt.claims', format(c, a), true);
  set local role authenticated;
  perform testkit.t('con plan: publicar', format('select public.set_event_status(%L, ''active'')->>''status''', e2), 'OK:active');
  perform testkit.t('con plan: estado', 'select public.trial_status()->>''state''', 'OK:subscribed');
  perform testkit.t('datos conservados', 'select count(*)::text from public.events', 'OK:3');
  perform testkit.t('historial comercial inmutable', 'delete from public.venue_commercial_log', '%permission denied%');
  perform set_config('request.jwt.claims', format(c, s), true);
  perform testkit.t('terminar plan exige motivo', format('select public.superadmin_end_plan(%L, '''')', a), 'reason_required');
  perform testkit.t('terminar plan', format('select public.superadmin_end_plan(%L, ''Fin del contrato'')::text', a), 'OK:%');
  perform set_config('request.jwt.claims', format(c, a), true);
  perform testkit.t('plan terminado: estado', 'select public.trial_status()->>''state''', 'OK:plan_ended');
  perform testkit.t('plan terminado: sin emisión', format('select public.create_ticket(%L,''X'',(select id from public.ticket_types where event_id = %L limit 1))', e2, e2), 'commercial_inactive');
  reset role;
  perform testkit.t('tarea programada registrada', 'select count(*)::text from cron.job where jobname = ''trial-notifications'' and active', 'OK:1');

  select count(*) filter (where ok) || ' PASS, ' || count(*) filter (where not ok) || ' FAIL. ' ||
         coalesce(string_agg(name || ' => ' || got, ' ;; ' order by n) filter (where not ok), '') into msg from testkit.r;
  raise exception 'RESULTS: %', msg;
end $t$;
