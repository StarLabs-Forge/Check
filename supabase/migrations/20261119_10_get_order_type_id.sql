-- 10 · get_order devuelve el id del tipo de entrada de cada línea
-- (la app lo necesita para resolver precios al abrir «Mi pedido»).
create or replace function public.get_order(p_order_id uuid, p_token text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  s public.order_secrets; o public.orders; e public.events; v public.venues;
  v_lines jsonb; v_tickets jsonb := '[]'::jsonb; v_bank jsonb := null;
begin
  select * into s from public.order_secrets where order_id = p_order_id;
  if not found or p_token is null
     or s.token_hash <> encode(extensions.digest(p_token, 'sha256'), 'hex') then
    raise exception 'not_found' using errcode = 'P0002';
  end if;

  update public.orders set status = 'expired'
   where id = p_order_id and status = 'awaiting_payment' and expires_at <= now();
  select * into o from public.orders where id = p_order_id;
  select * into e from public.events where id = o.event_id;
  select * into v from public.venues where owner_id = e.owner_id;

  select jsonb_agg(jsonb_build_object('type_id', t.id, 'type_name', t.name, 'qty', l.qty, 'unit_price', l.unit_price)
                   order by t.position, t.price)
    into v_lines
  from public.order_lines l join public.ticket_types t on t.id = l.ticket_type_id
  where l.order_id = o.id;

  if o.status in ('awaiting_payment','verifying') then
    v_bank := jsonb_build_object('beneficiary', v.bank_beneficiary, 'bank_name', v.bank_name,
                                 'account', v.bank_account, 'qr_path', v.bank_qr_path);
  end if;

  if o.status = 'approved' then
    select coalesce(jsonb_agg(jsonb_build_object(
             'ticket_id', tk.id, 'type_name', tt.name, 'status', tk.status,
             'qr_token', encode(extensions.hmac(tk.id::text, s.token_hash, 'sha256'), 'hex'))
           order by tk.created_at, tk.id), '[]'::jsonb)
      into v_tickets
    from public.tickets tk join public.ticket_types tt on tt.id = tk.ticket_type_id
    where tk.order_id = o.id;
  end if;

  return jsonb_build_object(
    'order', jsonb_build_object('id', o.id, 'number', o.number, 'status', o.status, 'total', o.total,
                                'buyer_name', o.buyer_name, 'created_at', o.created_at,
                                'expires_at', o.expires_at, 'declared_at', o.declared_at,
                                'decided_at', o.decided_at, 'reject_reason', o.reject_reason),
    'event', jsonb_build_object('id', e.id, 'name', e.name, 'starts_at', e.starts_at),
    'venue', jsonb_build_object('name', v.name, 'zone', v.zone),
    'bank', v_bank, 'lines', coalesce(v_lines, '[]'::jsonb), 'tickets', v_tickets);
end $$;
