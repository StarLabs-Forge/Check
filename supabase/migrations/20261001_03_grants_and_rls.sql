-- ===== Grants mínimos (columna por columna donde importa) =====
revoke all on all tables    in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;

grant select on public.plan_limits to authenticated;
grant select on public.profiles    to authenticated;
-- role, plan y status NO son editables por el usuario (solo super admin por SQL)
grant update (full_name, phone) on public.profiles to authenticated;

grant select on public.events to authenticated;
grant insert (owner_id, name, description, starts_at, ends_at, capacity, access_type, ticket_price)
  on public.events to authenticated;
grant update (name, description, starts_at, ends_at, capacity, access_type, ticket_price, status)
  on public.events to authenticated;

grant select on public.event_staff to authenticated;   -- escrituras solo vía RPC

grant select on public.tickets to authenticated;
grant update (guest_name, guest_phone) on public.tickets to authenticated;  -- pago/estado solo vía RPC

grant select on public.scan_logs to authenticated;     -- inserción solo vía RPC

-- ===== Policies =====
create policy plan_limits_read on public.plan_limits
  for select to authenticated using (true);

-- profiles
create policy profiles_select_own on public.profiles
  for select to authenticated using (id = (select auth.uid()));
create policy profiles_select_super on public.profiles
  for select to authenticated using ((select private.is_super_admin()));
create policy profiles_select_my_staff on public.profiles
  for select to authenticated using (private.admin_sees_profile(id));
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- events
create policy events_select on public.events
  for select to authenticated using (
    (select private.is_super_admin())
    or ((select private.current_user_role()) = 'admin' and owner_id = (select auth.uid()))
    or private.is_event_staff(id)
  );
create policy events_insert on public.events
  for insert to authenticated with check (
    (select private.current_user_role()) = 'admin' and owner_id = (select auth.uid())
  );
create policy events_update on public.events
  for update to authenticated
  using ((select private.current_user_role()) = 'admin' and owner_id = (select auth.uid()))
  with check ((select private.current_user_role()) = 'admin' and owner_id = (select auth.uid()));

-- event_staff
create policy event_staff_select on public.event_staff
  for select to authenticated using (
    (select private.is_super_admin())
    or private.owns_event(event_id)
    or staff_id = (select auth.uid())
  );

-- tickets (el staff NO lee la tabla: usa RPC validate_qr / search_tickets)
create policy tickets_select on public.tickets
  for select to authenticated using (
    (select private.is_super_admin()) or private.owns_event(event_id)
  );
create policy tickets_update on public.tickets
  for update to authenticated
  using (private.owns_event(event_id) and status = 'issued')
  with check (private.owns_event(event_id));

-- scan_logs
create policy scan_logs_select on public.scan_logs
  for select to authenticated using (
    (select private.is_super_admin()) or private.owns_event(event_id)
  );
