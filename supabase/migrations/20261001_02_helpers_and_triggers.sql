-- ===== Helpers de autorización (security definer, no expuestos por la API) =====
create function private.current_user_role()
returns public.user_role language sql stable security definer set search_path = '' as $$
  select p.role from public.profiles p
  where p.id = (select auth.uid()) and p.status = 'active'
$$;

create function private.is_super_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(private.current_user_role() = 'super_admin', false)
$$;

create function private.owns_event(p_event_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(private.current_user_role() = 'admin', false)
     and exists (select 1 from public.events e
                 where e.id = p_event_id and e.owner_id = (select auth.uid()))
$$;

create function private.is_event_staff(p_event_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(private.current_user_role() = 'staff', false)
     and exists (select 1
                 from public.event_staff es
                 join public.events e on e.id = es.event_id
                 where es.event_id = p_event_id
                   and es.staff_id = (select auth.uid())
                   and es.revoked_at is null
                   and e.status in ('active', 'live'))
$$;

-- Puede operar la puerta: staff asignado, o el dueño con el evento abierto
create function private.can_operate_door(p_event_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.is_event_staff(p_event_id)
      or (private.owns_event(p_event_id)
          and exists (select 1 from public.events e
                      where e.id = p_event_id and e.status in ('active', 'live')))
$$;

create function private.admin_sees_profile(p_profile uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1
                 from public.event_staff es
                 join public.events e on e.id = es.event_id
                 where es.staff_id = p_profile and e.owner_id = (select auth.uid()))
$$;

-- Código de staff: 10 chars, alfabeto de 32 símbolos sin ambiguos (sin I, O, 0, 1) => 50 bits, sin sesgo
create function private.gen_staff_code()
returns text language plpgsql volatile set search_path = '' as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  b bytea := extensions.gen_random_bytes(10);
  code text := '';
  i int;
begin
  for i in 0..9 loop
    code := code || substr(alphabet, (get_byte(b, i) % 32) + 1, 1);
  end loop;
  return code;
end $$;

-- ===== updated_at =====
create function private.set_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at := now(); return new; end $$;

create trigger profiles_updated_at before update on public.profiles
  for each row execute function private.set_updated_at();
create trigger events_updated_at before update on public.events
  for each row execute function private.set_updated_at();
create trigger tickets_updated_at before update on public.tickets
  for each row execute function private.set_updated_at();

-- ===== Alta automática de perfil =====
-- Todo registro real nace como 'admin' (nunca se confía en metadata del cliente).
-- Los anónimos (staff) NO reciben perfil aquí: lo crea redeem_staff_code().
create function private.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if coalesce(new.is_anonymous, false) then
    return new;
  end if;
  insert into public.profiles (id, full_name)
  values (new.id, left(coalesce(new.raw_user_meta_data ->> 'full_name',
                                new.raw_user_meta_data ->> 'name', ''), 120))
  on conflict (id) do nothing;
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- ===== Reglas de eventos (límites de plan + máquina de estados) =====
-- Si auth.uid() es null (SQL editor / service_role) o es super_admin, no se aplican.
create function private.guard_event()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_uid   uuid := auth.uid();
  v_max   int;
  v_count int;
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
  return new;
end $$;

create trigger events_guard
  before insert or update on public.events
  for each row execute function private.guard_event();

-- ===== scan_logs inmutable (incluso para service_role) =====
create function private.block_mutation()
returns trigger language plpgsql set search_path = '' as $$
begin
  raise exception 'scan_logs es inmutable' using errcode = '42501';
end $$;

create trigger scan_logs_immutable
  before update or delete on public.scan_logs
  for each row execute function private.block_mutation();
create trigger scan_logs_no_truncate
  before truncate on public.scan_logs
  for each statement execute function private.block_mutation();
