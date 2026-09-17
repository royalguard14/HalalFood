-- Developer-only permanent restaurant deletion.
-- This intentionally removes the restaurant and all application data directly tied to it.
-- Customer user_addresses and owner profiles are preserved.

create or replace function public.developer_delete_restaurant(p_restaurant_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_ids uuid[];
  v_deleted_orders integer := 0;
  v_deleted_order_items integer := 0;
  v_deleted_payments integer := 0;
  v_deleted_menu_items integer := 0;
  v_deleted_menu_categories integer := 0;
  v_deleted_favorites integer := 0;
  v_deleted_promos integer := 0;
  v_deleted_subscriptions integer := 0;
  v_deleted_verifications integer := 0;
  v_deleted_restaurant_categories integer := 0;
  v_deleted_hours integer := 0;
  v_deleted_photos integer := 0;
  v_deleted_subscription_payments integer := 0;
  v_deleted_restaurant integer := 0;
begin
  if not public.is_developer() then
    raise exception 'Only a Developer can permanently delete a restaurant';
  end if;

  if not exists (select 1 from public.restaurants where id = p_restaurant_id) then
    raise exception 'Restaurant not found';
  end if;

  select coalesce(array_agg(id), array[]::uuid[])
    into v_order_ids
  from public.orders
  where restaurant_id = p_restaurant_id;

  delete from public.payments where order_id = any(v_order_ids);
  get diagnostics v_deleted_payments = row_count;

  delete from public.order_items where order_id = any(v_order_ids);
  get diagnostics v_deleted_order_items = row_count;

  delete from public.orders where restaurant_id = p_restaurant_id;
  get diagnostics v_deleted_orders = row_count;

  delete from public.menu_items where restaurant_id = p_restaurant_id;
  get diagnostics v_deleted_menu_items = row_count;

  delete from public.menu_categories where restaurant_id = p_restaurant_id;
  get diagnostics v_deleted_menu_categories = row_count;

  delete from public.favorite_restaurants where restaurant_id = p_restaurant_id;
  get diagnostics v_deleted_favorites = row_count;

  delete from public.promo_codes where restaurant_id = p_restaurant_id;
  get diagnostics v_deleted_promos = row_count;

  delete from public.subscription_payments where restaurant_id = p_restaurant_id;
  get diagnostics v_deleted_subscription_payments = row_count;

  delete from public.restaurant_subscriptions where restaurant_id = p_restaurant_id;
  get diagnostics v_deleted_subscriptions = row_count;

  delete from public.halal_verifications where restaurant_id = p_restaurant_id;
  get diagnostics v_deleted_verifications = row_count;

  delete from public.restaurant_categories where restaurant_id = p_restaurant_id;
  get diagnostics v_deleted_restaurant_categories = row_count;

  delete from public.restaurant_hours where restaurant_id = p_restaurant_id;
  get diagnostics v_deleted_hours = row_count;

  delete from public.restaurant_photos where restaurant_id = p_restaurant_id;
  get diagnostics v_deleted_photos = row_count;

  delete from public.restaurants where id = p_restaurant_id;
  get diagnostics v_deleted_restaurant = row_count;

  return jsonb_build_object(
    'restaurant', v_deleted_restaurant,
    'orders', v_deleted_orders,
    'order_items', v_deleted_order_items,
    'payments', v_deleted_payments,
    'menu_items', v_deleted_menu_items,
    'menu_categories', v_deleted_menu_categories,
    'favorite_restaurants', v_deleted_favorites,
    'promo_codes', v_deleted_promos,
    'restaurant_subscriptions', v_deleted_subscriptions,
    'subscription_payments', v_deleted_subscription_payments,
    'halal_verifications', v_deleted_verifications,
    'restaurant_categories', v_deleted_restaurant_categories,
    'restaurant_hours', v_deleted_hours,
    'restaurant_photos', v_deleted_photos
  );
end;
$$;

revoke execute on function public.developer_delete_restaurant(uuid) from public;
revoke execute on function public.developer_delete_restaurant(uuid) from anon;
grant execute on function public.developer_delete_restaurant(uuid) to authenticated;
