-- Extensiones (en schema extensions, no en public)
create extension if not exists pgcrypto with schema extensions;
create extension if not exists pg_trgm with schema extensions;

-- Schema privado: helpers de RLS, NO expuesto por la API
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

-- Seguro por defecto: lo que se cree en public no queda abierto a anon/authenticated
alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;
alter default privileges in schema public revoke all on functions from anon, authenticated;

-- Enums
create type public.user_role      as enum ('super_admin', 'admin', 'staff');
create type public.plan_type      as enum ('starter', 'pro', 'premium');
create type public.account_status as enum ('active', 'suspended');
create type public.event_access   as enum ('free', 'paid');
create type public.event_status   as enum ('draft', 'active', 'live', 'finished', 'suspended');
create type public.payment_status as enum ('pending', 'paid');
create type public.ticket_status  as enum ('issued', 'used', 'cancelled');
create type public.scan_result    as enum (
  'valid', 'pending_payment', 'already_used', 'invalid', 'wrong_event',
  'cancelled', 'manual_checkin', 'payment_collected'
);

-- Límites por plan (editable sin tocar código)
create table public.plan_limits (
  plan                public.plan_type primary key,
  max_events_month    int check (max_events_month > 0),     -- null = ilimitado
  max_staff_per_event int check (max_staff_per_event > 0),
  max_tickets_month   int check (max_tickets_month > 0)
);
insert into public.plan_limits values
  ('starter', 4, 2, 200),
  ('pro', null, null, null),
  ('premium', null, null, null);

-- profiles: extiende auth.users
create table public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  full_name  text not null default '' check (char_length(full_name) <= 120),
  phone      text check (char_length(phone) <= 30),
  role       public.user_role not null default 'admin',
  plan       public.plan_type not null default 'starter',
  status     public.account_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- events (soft-delete vía status = 'suspended', nunca borrado físico)
create table public.events (
  id            uuid primary key default gen_random_uuid(),
  owner_id      uuid not null references public.profiles(id) on delete restrict,
  name          text not null check (char_length(name) between 1 and 120),
  description   text check (char_length(description) <= 2000),
  starts_at     timestamptz not null,
  ends_at       timestamptz not null,
  capacity      int not null check (capacity > 0),
  access_type   public.event_access not null default 'free',
  ticket_price  numeric(10,2) not null default 0,
  status        public.event_status not null default 'draft',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint events_dates_chk check (ends_at > starts_at),
  constraint events_price_chk check (
    (access_type = 'free' and ticket_price = 0) or
    (access_type = 'paid' and ticket_price > 0)
  )
);
create index events_owner_starts_idx on public.events (owner_id, starts_at desc);

-- event_staff: invitación por código (el staff no tiene email/password)
create table public.event_staff (
  id               uuid primary key default gen_random_uuid(),
  event_id         uuid not null references public.events(id) on delete restrict,
  staff_id         uuid references public.profiles(id) on delete restrict,
  display_name     text not null check (char_length(display_name) between 1 and 80),
  code_hash        text not null unique,
  code_expires_at  timestamptz not null,
  redeemed_at      timestamptz,
  revoked_at       timestamptz,
  created_by       uuid not null references public.profiles(id) on delete restrict,
  created_at       timestamptz not null default now(),
  constraint event_staff_redeemed_chk check ((redeemed_at is null) = (staff_id is null))
);
create index event_staff_event_idx on public.event_staff (event_id);
create index event_staff_staff_idx on public.event_staff (staff_id) where staff_id is not null;
create unique index event_staff_one_active_idx
  on public.event_staff (event_id, staff_id)
  where staff_id is not null and revoked_at is null;

-- tickets: el token QR en claro NUNCA se guarda, solo su hash SHA-256
create table public.tickets (
  id                    uuid primary key default gen_random_uuid(),
  event_id              uuid not null references public.events(id) on delete restrict,
  guest_name            text not null check (char_length(guest_name) between 1 and 120),
  guest_phone           text check (char_length(guest_phone) <= 30),
  qr_token_hash         text not null unique,
  payment_status        public.payment_status not null default 'pending',
  status                public.ticket_status not null default 'issued',
  payment_confirmed_at  timestamptz,
  payment_confirmed_by  uuid references public.profiles(id) on delete restrict,
  checked_in_at         timestamptz,
  checked_in_by         uuid references public.profiles(id) on delete restrict,
  created_by            uuid not null references public.profiles(id) on delete restrict,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  constraint tickets_used_chk check ((status = 'used') = (checked_in_at is not null)),
  constraint tickets_used_paid_chk check (status <> 'used' or payment_status = 'paid')
);
create index tickets_event_status_idx  on public.tickets (event_id, status);
create index tickets_event_payment_idx on public.tickets (event_id, payment_status);
create index tickets_name_trgm_idx     on public.tickets using gin (guest_name extensions.gin_trgm_ops);
create index tickets_created_by_idx    on public.tickets (created_by);

-- scan_logs: solo-inserción (inmutable)
create table public.scan_logs (
  id          bigint generated always as identity primary key,
  event_id    uuid not null references public.events(id) on delete restrict,
  ticket_id   uuid references public.tickets(id) on delete restrict,
  scanned_by  uuid not null references public.profiles(id) on delete restrict,
  result      public.scan_result not null,
  scanned_at  timestamptz not null default now()
);
create index scan_logs_event_time_idx on public.scan_logs (event_id, scanned_at desc);
create index scan_logs_ticket_idx     on public.scan_logs (ticket_id) where ticket_id is not null;
create index scan_logs_scanned_by_idx on public.scan_logs (scanned_by);

-- Intentos de canje de código de staff (anti fuerza bruta). Solo accesible por funciones.
create table private.redeem_attempts (
  id           bigint generated always as identity primary key,
  user_id      uuid not null,
  attempted_at timestamptz not null default now()
);
create index redeem_attempts_user_idx on private.redeem_attempts (user_id, attempted_at desc);

alter table public.plan_limits enable row level security;
alter table public.profiles    enable row level security;
alter table public.events      enable row level security;
alter table public.event_staff enable row level security;
alter table public.tickets     enable row level security;
alter table public.scan_logs   enable row level security;
