-- Customer Restaurant Discovery Radius
--
-- The platform-wide maximum_delivery_distance_km is used for two customer-facing
-- distance rules:
--   1. restaurant discovery: only restaurants within the radius are shown;
--   2. delivery ordering: the existing calculate_delivery_fee() rejects orders
--      beyond the same maximum distance.
--
-- Customers must not read delivery_pricing_settings directly because that table
-- also contains pricing configuration. This RPC exposes only the radius.
--
-- Applied to Supabase project taltqnxhivpfwjqlvxnt.

create or replace function public.get_customer_restaurant_radius_km()
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select d.maximum_delivery_distance_km
      from public.delivery_pricing_settings d
      order by d.updated_at desc
      limit 1
    ),
    0
  );
$$;

revoke execute on function public.get_customer_restaurant_radius_km() from public;
revoke execute on function public.get_customer_restaurant_radius_km() from anon;
grant execute on function public.get_customer_restaurant_radius_km() to authenticated;
