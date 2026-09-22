-- Customer Delivery Downpayment receipt submission
-- Live function: public.submit_delivery_downpayment_receipt(uuid, text)

create or replace function public.submit_delivery_downpayment_receipt(
  p_order_id uuid,
  p_receipt_path text
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_order public.orders%rowtype;
begin
  if v_user_id is null then
    raise exception 'User is not authenticated.';
  end if;

  if p_receipt_path is null or trim(p_receipt_path) = '' then
    raise exception 'Receipt path is required.';
  end if;

  select *
    into v_order
  from public.orders
  where id = p_order_id
    and customer_id = v_user_id
  for update;

  if not found then
    raise exception 'Delivery order not found.';
  end if;

  if v_order.fulfillment_type <> 'delivery' then
    raise exception 'This is not a delivery order.';
  end if;

  if v_order.pickup_downpayment_status not in ('pending', 'receipt_rejected') then
    raise exception 'This order is not waiting for a downpayment receipt.';
  end if;

  update public.orders
  set pickup_receipt_path = trim(p_receipt_path),
      pickup_receipt_submitted_at = now(),
      pickup_receipt_rejection_reason = null,
      pickup_downpayment_status = 'receipt_submitted',
      updated_at = now()
  where id = p_order_id;
end;
$function$;

revoke all on function public.submit_delivery_downpayment_receipt(uuid, text) from public;
revoke all on function public.submit_delivery_downpayment_receipt(uuid, text) from anon;
grant execute on function public.submit_delivery_downpayment_receipt(uuid, text) to authenticated;
