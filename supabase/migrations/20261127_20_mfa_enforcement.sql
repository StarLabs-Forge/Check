-- 20 · MFA TOTP obligatorio (aal2) para administradores y superadministradores,
--      exigido en el servidor, y recuperación auditada.
--
-- INTERRUPTOR DE DESPLIEGUE: platform_settings.mfa_required (por defecto false).
-- Activarlo SOLO cuando la verificación de correo por OTP esté validada y la app
-- con la pantalla MFA esté publicada.

alter table public.platform_settings add column mfa_required boolean not null default false;

create table public.mfa_resets (
  id            bigint generated always as identity primary key,
  target_id     uuid not null references public.profiles(id),
  authorized_by uuid not null references public.profiles(id),
  reason        text not null check (char_length(btrim(reason)) between 10 and 300),
  created_at    timestamptz not null default now()
);
alter table public.mfa_resets enable row level security;
create policy mfa_resets_select on public.mfa_resets for select to authenticated
  using ((select private.is_super_admin()));
grant select on public.mfa_resets to authenticated;
create trigger mfa_resets_immutable before update or delete on public.mfa_resets
  for each row execute function private.block_audit_mutation();

-- true si la sesión puede ejercer su rol. Para roles privilegiados exige: sesión aal2,
-- un factor TOTP verificado que siga existiendo, y que el TOTP se haya validado
-- DESPUÉS del último restablecimiento (los tokens antiguos dejan de servir).
create or replace function private.mfa_ok() returns boolean
language sql stable security definer set search_path = '' as $$
  select case
    when not coalesce((select s.mfa_required from public.platform_settings s where s.id), false) then true
    when not exists (select 1 from public.profiles p
                     where p.id = (select auth.uid()) and p.role in ('admin', 'super_admin')) then true
    else coalesce(auth.jwt() ->> 'aal', 'aal1') = 'aal2'
     and exists (select 1 from auth.mfa_factors f
                 where f.user_id = (select auth.uid()) and f.status = 'verified' and f.factor_type = 'totp')
     and coalesce((select max((a ->> 'timestamp')::bigint)
                   from jsonb_array_elements(coalesce(auth.jwt() -> 'amr', '[]'::jsonb)) a
                   where a ->> 'method' = 'totp'), 0)
       > coalesce((select floor(extract(epoch from max(r.created_at)))::bigint
                   from public.mfa_resets r where r.target_id = (select auth.uid())), 0)
  end
$$;
revoke all on function private.mfa_ok() from public, anon;
grant execute on function private.mfa_ok() to authenticated;

-- Punto central: todo RPC y política que consulta el rol queda cubierto.
create or replace function private.current_user_role()
returns public.user_role language sql stable security definer set search_path = '' as $$
  select p.role from public.profiles p
  where p.id = (select auth.uid()) and p.status = 'active' and private.mfa_ok()
$$;

-- Políticas RESTRICTIVAS: se combinan con AND, así que ninguna política permisiva
-- (p. ej. "owner_id = auth.uid()") puede eludir el segundo factor.
do $$
declare t text;
begin
  for t in select c.relname from pg_class c
           where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and c.relrowsecurity
             and c.relname <> 'profiles'
  loop
    execute format('create policy mfa_restrict on public.%I as restrictive for all to authenticated '
                   'using ((select private.mfa_ok())) with check ((select private.mfa_ok()))', t);
  end loop;
end $$;
-- profiles: siempre se puede leer el perfil propio (la app necesita el rol para pedir MFA).
create policy mfa_restrict_select on public.profiles as restrictive for select to authenticated
  using (id = (select auth.uid()) or (select private.mfa_ok()));
create policy mfa_restrict_update on public.profiles as restrictive for update to authenticated
  using ((select private.mfa_ok())) with check ((select private.mfa_ok()));

-- Funciones que autorizaban solo por auth.uid().
create or replace function public.staff_event_ids(p_staff_id uuid) returns uuid[]
language sql stable security definer set search_path = '' as $$
  select coalesce(array_agg(es.event_id), '{}')
    from public.event_staff es join public.events e on e.id = es.event_id
   where es.staff_id = p_staff_id and es.revoked_at is null and e.owner_id = auth.uid() and private.mfa_ok()
$$;

create or replace function public.session_mfa_status() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'role', p.role,
    'required', coalesce(s.mfa_required, false) and p.role in ('admin', 'super_admin'),
    'satisfied', private.mfa_ok(),
    'enrolled', exists (select 1 from auth.mfa_factors f
                        where f.user_id = p.id and f.status = 'verified' and f.factor_type = 'totp'))
  from public.profiles p left join public.platform_settings s on s.id
  where p.id = auth.uid()
$$;
revoke all on function public.session_mfa_status() from public, anon;
grant execute on function public.session_mfa_status() to authenticated;

alter table public.platform_log drop constraint platform_log_action_check;
alter table public.platform_log add constraint platform_log_action_check check (action = any (array[
  'venue_suspended','venue_activated','plan_changed','venue_created','plan_limits_changed',
  'settings_changed','mfa_reset']));

-- Autoriza y registra el restablecimiento del MFA de un administrador. Los factores los
-- elimina la Edge Function `mfa-reset` con la Admin API; la revocación de sesiones se
-- añade en la migración 21. Desde este momento los tokens anteriores ya no ejercen el
-- rol (mfa_ok exige un TOTP posterior al restablecimiento y un factor vigente).
-- El superadministrador NO se recupera por esta vía (ver docs/super-admin.md).
create or replace function public.superadmin_authorize_mfa_reset(p_user_id uuid, p_reason text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_reason text := btrim(coalesce(p_reason, ''));
begin
  if v_uid is null or not private.is_super_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  if char_length(v_reason) < 10 then raise exception 'reason_required' using errcode = 'P0001'; end if;
  if not exists (select 1 from public.profiles where id = p_user_id and role = 'admin') then
    raise exception 'target_not_admin' using errcode = 'P0001';
  end if;
  insert into public.mfa_resets (target_id, authorized_by, reason) values (p_user_id, v_uid, left(v_reason, 300));
  insert into public.platform_log (actor_id, action, target_owner_id, detail)
  values (v_uid, 'mfa_reset', p_user_id, left(v_reason, 200));
  return jsonb_build_object('result', 'ok');
end $$;
revoke all on function public.superadmin_authorize_mfa_reset(uuid, text) from public, anon;
grant execute on function public.superadmin_authorize_mfa_reset(uuid, text) to authenticated;
