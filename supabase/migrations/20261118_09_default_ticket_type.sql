-- 09 · Un evento de pago siempre tiene al menos un tipo de entrada «General»
-- (precio y capacidad del evento), para que pueda venderse por la web pública.
-- El admin puede ajustar o agregar tipos después.
create function private.ensure_default_ticket_type() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.access_type = 'paid' and new.ticket_price > 0 and new.capacity > 0
     and not exists (select 1 from public.ticket_types t where t.event_id = new.id) then
    insert into public.ticket_types (event_id, name, price, capacity, max_per_order, position)
    values (new.id, 'General', new.ticket_price, new.capacity, 6, 0);
  end if;
  return new;
end $$;
revoke all on function private.ensure_default_ticket_type() from public, anon, authenticated;

create trigger events_default_ticket_type
  after insert or update of access_type, ticket_price, capacity on public.events
  for each row execute function private.ensure_default_ticket_type();

-- Backfill de eventos de pago existentes
insert into public.ticket_types (event_id, name, price, capacity, max_per_order, position)
select e.id, 'General', e.ticket_price, e.capacity, 6, 0
from public.events e
where e.access_type = 'paid' and e.ticket_price > 0 and e.capacity > 0
  and not exists (select 1 from public.ticket_types t where t.event_id = e.id);
