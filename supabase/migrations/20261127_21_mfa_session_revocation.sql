-- 21 · El restablecimiento de MFA también revoca las sesiones del administrador afectado.
-- Elimina filas de auth.sessions de ESE usuario (cierra sus sesiones); no toca datos de negocio.
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
  delete from auth.sessions where user_id = p_user_id;   -- revoca sesiones y refresh tokens
  return jsonb_build_object('result', 'ok');
end $$;
