-- Preferencias de avisos del local. Una fila por dueño; solo él la lee y la edita.
create table if not exists public.venue_settings (
  owner_id uuid primary key references public.profiles(id) on delete cascade,
  notify_new_payment boolean not null default true,
  notify_low_capacity boolean not null default true,
  notify_daily_summary boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table public.venue_settings enable row level security;

create policy venue_settings_select on public.venue_settings
  for select to authenticated using (owner_id = (select auth.uid()));
create policy venue_settings_insert on public.venue_settings
  for insert to authenticated
  with check (owner_id = (select auth.uid()) and (select private.current_user_role()) = 'admin');
create policy venue_settings_update on public.venue_settings
  for update to authenticated
  using (owner_id = (select auth.uid()) and (select private.current_user_role()) = 'admin')
  with check (owner_id = (select auth.uid()));

revoke all on public.venue_settings from anon, public;
grant select, insert, update on public.venue_settings to authenticated;

drop trigger if exists venue_settings_updated_at on public.venue_settings;
create trigger venue_settings_updated_at before update on public.venue_settings
  for each row execute function private.set_updated_at();
