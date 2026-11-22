-- 06 · Pedidos públicos, pagos delegados, auditoría (solo cambios aditivos)
-- Modelo: 1 local (venue) = 1 admin. El comprador es invitado (sin cuenta) y
-- solo accede a su pedido con un token que se guarda hasheado.

create type public.order_status as enum
  ('awaiting_payment','verifying','approved','rejected','expired','cancelled');

-- ───────── Local (datos de cobro) ─────────
create table public.venues (
  id               uuid primary key default gen_random_uuid(),
  owner_id         uuid not null unique references public.profiles(id) on delete cascade,
  name             text not null check (char_length(btrim(name)) between 1 and 120),
  zone             text check (char_length(zone) <= 80),
  bank_beneficiary text check (char_length(bank_beneficiary) <= 120),
  bank_name        text check (char_length(bank_name) <= 80),
  bank_account     text check (char_length(bank_account) <= 40),
  bank_qr_path     text check (char_length(bank_qr_path) <= 300),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create trigger venues_updated_at before update on public.venues
  for each row execute function private.set_updated_at();

-- Backfill: un local por cada admin existente, con el nombre que dio al registrarse
insert into public.venues (owner_id, name)
select p.id,
       left(coalesce(nullif(btrim(u.raw_user_meta_data ->> 'venue_name'), ''),
                     nullif(btrim(p.full_name), ''), 'Mi local'), 120)
from public.profiles p join auth.users u on u.id = p.id
where p.role = 'admin'
on conflict (owner_id) do nothing;

-- ───────── Tipos de entrada ─────────
create table public.ticket_types (
  id            uuid primary key default gen_random_uuid(),
  event_id      uuid not null references public.events(id) on delete cascade,
  name          text not null check (char_length(btrim(name)) between 1 and 60),
  price         numeric(10,2) not null check (price >= 0),
  capacity      integer not null check (capacity > 0),
  max_per_order integer not null default 6 check (max_per_order between 1 and 20),
  position      integer not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (event_id, name)
);
create index ticket_types_event_idx on public.ticket_types (event_id);
create trigger ticket_types_updated_at before update on public.ticket_types
  for each row execute function private.set_updated_at();

-- ───────── Pedidos ─────────
create sequence public.order_number_seq start 1001;

create table public.orders (
  id            uuid primary key default gen_random_uuid(),
  number        text not null unique default ('CHK-' || nextval('public.order_number_seq')::text),
  event_id      uuid not null references public.events(id),
  buyer_name    text not null check (char_length(btrim(buyer_name)) between 2 and 120),
  buyer_ci      text not null check (char_length(buyer_ci) between 4 and 20),
  buyer_phone   text not null check (char_length(buyer_phone) between 6 and 30),
  buyer_email   text check (char_length(buyer_email) <= 200),
  total         numeric(10,2) not null check (total > 0),
  status        public.order_status not null default 'awaiting_payment',
  created_at    timestamptz not null default now(),
  expires_at    timestamptz not null default (now() + interval '15 minutes'),
  declared_at   timestamptz,
  decided_at    timestamptz,
  decided_by    uuid references public.profiles(id),
  reject_reason text check (char_length(reject_reason) <= 300),
  constraint orders_decision_complete check
    (status not in ('approved','rejected') or (decided_at is not null and decided_by is not null)),
  constraint orders_reject_needs_reason check
    (status <> 'rejected' or char_length(btrim(coalesce(reject_reason, ''))) > 0)
);
create index orders_event_status_idx on public.orders (event_id, status);
create index orders_open_idx on public.orders (expires_at) where status = 'awaiting_payment';
create index orders_buyer_ci_idx on public.orders (event_id, buyer_ci);

-- El token del comprador vive aparte, sin ningún permiso para anon/authenticated
create table public.order_secrets (
  order_id   uuid primary key references public.orders(id) on delete cascade,
  token_hash text not null unique
);

create table public.order_lines (
  order_id       uuid not null references public.orders(id) on delete cascade,
  ticket_type_id uuid not null references public.ticket_types(id),
  qty            integer not null check (qty between 1 and 20),
  unit_price     numeric(10,2) not null check (unit_price >= 0),
  primary key (order_id, ticket_type_id)
);
create index order_lines_type_idx on public.order_lines (ticket_type_id);

-- Los tickets nacidos de un pedido quedan enlazados
alter table public.tickets
  add column order_id       uuid references public.orders(id),
  add column ticket_type_id uuid references public.ticket_types(id);
create index tickets_order_idx on public.tickets (order_id) where order_id is not null;

-- Un pedido decidido (aprobado/rechazado/vencido/cancelado) nunca se reactiva
create function private.guard_order() returns trigger
language plpgsql set search_path = '' as $$
begin
  if old.status in ('approved','rejected','expired','cancelled') and new.status <> old.status then
    raise exception 'order_final' using errcode = 'P0001',
      hint = 'La decisión sobre un pedido es definitiva.';
  end if;
  if new.event_id <> old.event_id or new.total <> old.total
     or new.buyer_ci <> old.buyer_ci or new.number <> old.number then
    raise exception 'order_immutable' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger orders_guard before update on public.orders
  for each row execute function private.guard_order();

-- ───────── Verificadores delegados ─────────
create table public.payment_verifiers (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null references public.profiles(id) on delete cascade,
  verifier_id uuid not null references public.profiles(id) on delete cascade,
  granted_at  timestamptz not null default now(),
  revoked_at  timestamptz,
  check (owner_id <> verifier_id)
);
create unique index payment_verifiers_active_uq
  on public.payment_verifiers (owner_id, verifier_id) where revoked_at is null;
create index payment_verifiers_verifier_idx
  on public.payment_verifiers (verifier_id) where revoked_at is null;

-- ───────── Auditoría (inmutable) ─────────
create table public.audit_log (
  id               bigint generated always as identity primary key,
  owner_id         uuid not null references public.profiles(id),
  actor_id         uuid not null references public.profiles(id),
  actor_permission text not null check (actor_permission in ('admin','verifier')),
  action           text not null check (action in
    ('order_approved','order_rejected','payment_conflict','verifier_granted','verifier_revoked')),
  result           text not null check (char_length(result) <= 40),
  order_id         uuid references public.orders(id),
  reason           text check (char_length(reason) <= 300),
  created_at       timestamptz not null default now()
);
create index audit_log_owner_idx on public.audit_log (owner_id, created_at desc);
create index audit_log_actor_idx on public.audit_log (actor_id, created_at desc);

create function private.block_audit_mutation() returns trigger
language plpgsql set search_path = '' as $$
begin
  raise exception 'audit_log es inmutable' using errcode = '42501';
end $$;
create trigger audit_log_immutable before update or delete on public.audit_log
  for each row execute function private.block_audit_mutation();

-- ───────── Helpers de permiso ─────────
create function private.can_verify_payments(p_event_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select private.owns_event(p_event_id)
      or (coalesce(private.current_user_role() = 'staff', false)
          and exists (select 1
                      from public.events e
                      join public.payment_verifiers pv on pv.owner_id = e.owner_id
                      where e.id = p_event_id
                        and pv.verifier_id = (select auth.uid())
                        and pv.revoked_at is null))
$$;

create function private.can_see_order(p_order_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.orders o
                 where o.id = p_order_id and private.can_verify_payments(o.event_id))
$$;

-- ───────── RLS ─────────
alter table public.venues            enable row level security;
alter table public.ticket_types      enable row level security;
alter table public.orders            enable row level security;
alter table public.order_secrets     enable row level security;
alter table public.order_lines       enable row level security;
alter table public.payment_verifiers enable row level security;
alter table public.audit_log         enable row level security;

create policy venues_select on public.venues for select to authenticated
  using (owner_id = (select auth.uid()));
create policy venues_insert on public.venues for insert to authenticated
  with check (owner_id = (select auth.uid()) and (select private.current_user_role()) = 'admin');
create policy venues_update on public.venues for update to authenticated
  using (owner_id = (select auth.uid()) and (select private.current_user_role()) = 'admin')
  with check (owner_id = (select auth.uid()));

create policy ticket_types_select on public.ticket_types for select to authenticated
  using (private.owns_event(event_id) or private.is_event_staff(event_id));
create policy ticket_types_insert on public.ticket_types for insert to authenticated
  with check (private.owns_event(event_id));
create policy ticket_types_update on public.ticket_types for update to authenticated
  using (private.owns_event(event_id)) with check (private.owns_event(event_id));
create policy ticket_types_delete on public.ticket_types for delete to authenticated
  using (private.owns_event(event_id));

create policy orders_select on public.orders for select to authenticated
  using (private.can_verify_payments(event_id));
create policy order_lines_select on public.order_lines for select to authenticated
  using (private.can_see_order(order_id));
create policy payment_verifiers_select on public.payment_verifiers for select to authenticated
  using (owner_id = (select auth.uid()) or verifier_id = (select auth.uid()));
create policy audit_log_select on public.audit_log for select to authenticated
  using (owner_id = (select auth.uid()) or actor_id = (select auth.uid()));

-- ───────── Privilegios (todo lo que no se otorga queda denegado) ─────────
revoke all on public.venues, public.ticket_types, public.orders, public.order_secrets,
              public.order_lines, public.payment_verifiers, public.audit_log
  from anon, authenticated;
grant usage on schema private to authenticated;
grant execute on function private.can_verify_payments(uuid), private.can_see_order(uuid)
  to authenticated;

grant select on public.venues to authenticated;
grant insert (owner_id, name, zone, bank_beneficiary, bank_name, bank_account, bank_qr_path)
  on public.venues to authenticated;
grant update (name, zone, bank_beneficiary, bank_name, bank_account, bank_qr_path)
  on public.venues to authenticated;

grant select, delete on public.ticket_types to authenticated;
grant insert (event_id, name, price, capacity, max_per_order, position) on public.ticket_types to authenticated;
grant update (name, price, capacity, max_per_order, position) on public.ticket_types to authenticated;

grant select on public.orders, public.order_lines, public.payment_verifiers, public.audit_log
  to authenticated;
grant select (order_id, ticket_type_id) on public.tickets to authenticated;

-- Realtime para que el admin vea llegar pagos (respeta RLS)
do $$ begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'orders') then
    alter publication supabase_realtime add table public.orders;
  end if;
end $$;
