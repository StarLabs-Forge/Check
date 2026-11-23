-- Edición de eventos: guard_event ahora impide cambios que dejen ventas inconsistentes
-- y un trigger mantiene sincronizado el ticket_type "General" con capacidad y precio.

create or replace function private.guard_event()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_uid   uuid := auth.uid();
  v_max   int;
  v_count int;
  v_sold  int;
  v_held  int;
begin
  if v_uid is null or private.is_super_admin() then
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.status := 'draft';

    select pl.max_events_month into v_max
    from public.profiles p join public.plan_limits pl on pl.plan = p.plan
    where p.id = new.owner_id;

    if v_max is not null then
      select count(*) into v_count
      from public.events e
      where e.owner_id = new.owner_id
        and e.status <> 'suspended'
        and date_trunc('month', e.starts_at at time zone 'America/La_Paz')
          = date_trunc('month', new.starts_at at time zone 'America/La_Paz');
      if v_count >= v_max then
        raise exception 'plan_limit_events' using errcode = 'P0001',
          hint = 'El plan permite ' || v_max || ' eventos por mes.';
      end if;
    end if;
    return new;
  end if;

  -- UPDATE
  if new.owner_id <> old.owner_id then
    raise exception 'owner_immutable' using errcode = '42501';
  end if;
  if old.status in ('suspended', 'finished') then
    raise exception 'event_locked' using errcode = 'P0001',
      hint = 'Un evento suspendido o finalizado no se puede modificar.';
  end if;
  if new.status <> old.status then
    if (old.status::text, new.status::text) not in
       (('draft','active'), ('active','draft'), ('active','live'),
        ('live','finished'), ('active','finished')) then
      raise exception 'invalid_status_transition' using errcode = 'P0001',
        hint = old.status::text || ' -> ' || new.status::text;
    end if;
  end if;

  if new.ends_at <= new.starts_at then
    raise exception 'invalid_dates' using errcode = 'P0001',
      hint = 'El fin debe ser posterior al inicio.';
  end if;

  select count(*) into v_sold from public.tickets t
   where t.event_id = old.id and t.status <> 'cancelled';
  select coalesce(sum(private.held_seats(tt.id)), 0) into v_held from public.ticket_types tt
   where tt.event_id = old.id;

  if new.capacity < greatest(v_sold, v_held) then
    raise exception 'capacity_below_sold' using errcode = 'P0001',
      hint = 'Ya hay ' || greatest(v_sold, v_held) || ' entradas vendidas o reservadas.';
  end if;

  if (new.ticket_price <> old.ticket_price or new.access_type <> old.access_type)
     and greatest(v_sold, v_held) > 0 then
    raise exception 'price_locked_with_sales' using errcode = 'P0001',
      hint = 'No se puede cambiar el precio ni el tipo de acceso con entradas vendidas.';
  end if;

  -- Mover el evento a otro mes vuelve a validar el límite mensual del plan.
  if date_trunc('month', new.starts_at at time zone 'America/La_Paz')
     <> date_trunc('month', old.starts_at at time zone 'America/La_Paz') then
    select pl.max_events_month into v_max
    from public.profiles p join public.plan_limits pl on pl.plan = p.plan
    where p.id = new.owner_id;
    if v_max is not null then
      select count(*) into v_count
      from public.events e
      where e.owner_id = new.owner_id and e.id <> new.id
        and e.status <> 'suspended'
        and date_trunc('month', e.starts_at at time zone 'America/La_Paz')
          = date_trunc('month', new.starts_at at time zone 'America/La_Paz');
      if v_count >= v_max then
        raise exception 'plan_limit_events' using errcode = 'P0001',
          hint = 'El plan permite ' || v_max || ' eventos por mes.';
      end if;
    end if;
  end if;
  return new;
end $function$;

-- Mantiene el tipo de entrada único ("General") alineado con el evento.
create or replace function private.sync_default_ticket_type()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
begin
  if (new.capacity <> old.capacity or new.ticket_price <> old.ticket_price)
     and (select count(*) from public.ticket_types t where t.event_id = new.id) = 1 then
    update public.ticket_types
       set capacity = new.capacity,
           price = case when new.access_type = 'paid' and new.ticket_price > 0 then new.ticket_price else price end
     where event_id = new.id;
  end if;
  return null;
end $function$;

drop trigger if exists events_sync_ticket_type on public.events;
create trigger events_sync_ticket_type after update on public.events
  for each row execute function private.sync_default_ticket_type();

revoke all on function private.sync_default_ticket_type() from public, anon, authenticated;
