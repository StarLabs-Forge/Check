alter table public.staff_accounts
  add column email text not null default '',
  add column full_name text not null default '';
create unique index staff_accounts_owner_email_uq on public.staff_accounts (owner_id, lower(email)) where email <> '';
