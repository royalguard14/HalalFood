-- Developer-only permanent order deletion.
-- Deletes order data in PostgreSQL and returns receipt paths for Storage cleanup by the app.

create or replace function public.developer_delete_order(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_receipt_paths text[] := array[]::text[];
  v_deleted_order_items integer := 0;
  v_deleted_payments integer := 0;
  v_deleted_promo_redemptions integer := 0;
  v_deleted_orders integer := 0;
begin
  if not public.is_developer() then
    raise exception 'Only a Developer can permanently delete an order';
  end if;

  if not exists (select 1 from public.orders where id = p_order_id) then
    raise exception 'Order not found';
  end if;

  select coalesce(
    array_agg(distinct pickup_receipt_path) filter (
      where pickup_receipt_path is not null
        and btrim(pickup_receipt_path) <> ''
    ),
    array[]::text[]
  )
  into v_receipt_paths
  from public.orders
  where id = p_order_id;

  delete from public.payments where order_id = p_order_id;
  get diagnostics v_deleted_payments = row_count;

  delete from public.promo_redemptions where order_id = p_order_id;
  get diagnostics v_deleted_promo_redemptions = row_count;

  delete from public.order_items where order_id = p_order_id;
  get diagnostics v_deleted_order_items = row_count;

  delete from public.orders where id = p_order_id;
  get diagnostics v_deleted_orders = row_count;

  return jsonb_build_object(
    'order', v_deleted_orders,
    'order_items', v_deleted_order_items,
    'payments', v_deleted_payments,
    'promo_redemptions', v_deleted_promo_redemptions,
    'receipt_paths', to_jsonb(v_receipt_paths)
  );
end;
$$;

revoke execute on function public.developer_delete_order(uuid) from public;
revoke execute on function public.developer_delete_order(uuid) from anon;
grant execute on function public.developer_delete_order(uuid) to authenticated;


-- Developer-only order listing for the permanent deletion screen.
-- SECURITY DEFINER bypasses normal orders RLS, but the function itself requires Developer access.
create or replace function public.developer_list_orders()
returns setof public.orders
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_developer() then
    raise exception 'Only a Developer can view developer order management';
  end if;

  return query
    select o.*
    from public.orders o
    order by o.created_at desc;
end;
$$;

revoke execute on function public.developer_list_orders() from public;
revoke execute on function public.developer_list_orders() from anon;
grant execute on function public.developer_list_orders() to authenticated;
