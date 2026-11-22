-- Super admin: ajustes de plataforma, planes editables, lista de administradores
-- y registro cerrado. No expone empleados ni compradores de los locales.

-- 1) platform_log: nuevas acciones y destino opcional (ajustes globales no tienen local).
alter table public.platform_log alter column target_owner_id drop not null;
alter table public.platform_log drop constraint if exists platform_log_action_check;
alter table public.platform_log add constraint platform_log_action_check check (
  action = any (array['venue_suspended','venue_activated','plan_changed',
                      'venue_created','plan_limits_changed','settings_changed'])
);

-- 2) Precio mensual por plan (Bs.).
alter table public.plan_limits add column if not exists price_bs numeric(10,2) not null default 0
  check (price_bs >= 0);

-- 3) Ajustes de plataforma (una sola fila).
create table if not exists public.platform_settings (
  id boolean primary key default true check (id),
  registration_open boolean not null default true,
  maintenance boolean not null default false,
  maintenance_message text check (char_length(maintenance_message) <= 300),
  default_plan public.plan_type not null default 'starter',
  updated_at timestamptz not null default now(),
  updated_by uuid
);
insert into public.platform_settings (id) values (true) on conflict do nothing;

alter table public.platform_settings enable row level security;
create policy platform_settings_select on public.platform_settings
  for select to authenticated using ((select private.is_super_admin()));
revoke all on public.platform_settings from anon, public;
grant select on public.platform_settings to authenticated;

-- 4) Estado público mínimo (la app lo lee antes de iniciar sesión).
create or replace function public.platform_status()
returns jsonb
language sql
stable security definer
set search_path to ''
as $$
  select jsonb_build_object(
    'registration_open', s.registration_open,
    'maintenance', s.maintenance,
    'message', s.maintenance_message)
  from public.platform_settings s where s.id
$$;
revoke all on function public.platform_status() from public;
grant execute on function public.platform_status() to anon, authenticated;

-- 5) Registro cerrado: los registros por cuenta propia nacen suspendidos; las cuentas
--    creadas por el sistema (Edge Functions con service role) llevan app_metadata.provisioned.
--    El plan inicial sale de platform_settings.default_plan.
create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_open boolean;
  v_plan public.plan_type;
begin
  if coalesce(new.is_anonymous, false) then
    return new;
  end if;
  select registration_open, default_plan into v_open, v_plan from public.platform_settings where id;
  insert into public.profiles (id, full_name, plan, status)
  values (new.id,
          left(coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', ''), 120),
          coalesce(v_plan, 'starter'),
          case when coalesce(v_open, true) or (new.raw_app_meta_data ->> 'provisioned') = 'true'
               then 'active'::public.account_status else 'suspended'::public.account_status end)
  on conflict (id) do nothing;
  return new;
end $function$;

-- 6) RPC del super admin.
create or replace function public.superadmin_update_settings(
  p_registration_open boolean, p_maintenance boolean, p_message text, p_default_plan public.plan_type)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
declare v_uid uuid := auth.uid(); v_old public.platform_settings;
begin
  if not private.is_super_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  if char_length(coalesce(p_message, '')) > 300 then
    raise exception 'message_too_long' using errcode = 'P0001';
  end if;
  select * into v_old from public.platform_settings where id for update;
  update public.platform_settings
     set registration_open = coalesce(p_registration_open, registration_open),
         maintenance = coalesce(p_maintenance, maintenance),
         maintenance_message = nullif(btrim(p_message), ''),
         default_plan = coalesce(p_default_plan, default_plan),
         updated_at = now(), updated_by = v_uid
   where id;
  insert into public.platform_log (actor_id, action, detail)
  values (v_uid, 'settings_changed',
          left('registro=' || coalesce(p_registration_open, v_old.registration_open)::text
               || ' mantenimiento=' || coalesce(p_maintenance, v_old.maintenance)::text
               || ' plan=' || coalesce(p_default_plan, v_old.default_plan)::text, 200));
end $function$;

create or replace function public.superadmin_update_plan(
  p_plan public.plan_type, p_max_events int, p_max_staff int, p_max_tickets int, p_price numeric)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
declare v_uid uuid := auth.uid();
begin
  if not private.is_super_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  if coalesce(p_max_events, 0) < 0 or coalesce(p_max_staff, 0) < 0 or coalesce(p_max_tickets, 0) < 0
     or coalesce(p_price, 0) < 0 then
    raise exception 'invalid_limits' using errcode = 'P0001';
  end if;
  update public.plan_limits
     set max_events_month = p_max_events, max_staff_per_event = p_max_staff,
         max_tickets_month = p_max_tickets, price_bs = coalesce(p_price, 0)
   where plan = p_plan;
  if not found then raise exception 'plan_not_found' using errcode = 'P0001'; end if;
  insert into public.platform_log (actor_id, action, detail)
  values (v_uid, 'plan_limits_changed', left(p_plan::text, 200));
end $function$;

create or replace function public.superadmin_users()
returns jsonb
language plpgsql
stable security definer
set search_path to ''
as $function$
begin
  if not private.is_super_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
      'owner_id', p.id, 'full_name', p.full_name, 'email', u.email,
      'venue_name', coalesce(v.name, 'Sin nombre'), 'plan', p.plan, 'status', p.status,
      'created_at', p.created_at, 'last_sign_in_at', u.last_sign_in_at
    ) order by p.created_at desc), '[]'::jsonb)
    from public.profiles p
    join auth.users u on u.id = p.id
    left join public.venues v on v.owner_id = p.id
    where p.role = 'admin');
end $function$;

revoke all on function public.superadmin_update_settings(boolean, boolean, text, public.plan_type) from public, anon;
revoke all on function public.superadmin_update_plan(public.plan_type, int, int, int, numeric) from public, anon;
revoke all on function public.superadmin_users() from public, anon;
grant execute on function public.superadmin_update_settings(boolean, boolean, text, public.plan_type) to authenticated;
grant execute on function public.superadmin_update_plan(public.plan_type, int, int, int, numeric) to authenticated;
grant execute on function public.superadmin_users() to authenticated;
