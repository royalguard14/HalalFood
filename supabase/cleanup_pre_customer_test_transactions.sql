-- HALAL Food
-- Remove pre-Customer test transaction data while preserving the schema.
-- Safe for the current development stage: Customer ordering is not yet active.

begin;

delete from public.order_items
where order_id in (select id from public.orders);

delete from public.orders;
delete from public.payments;

delete from public.user_addresses ua
where not exists (
  select 1
  from public.orders o
  where o.delivery_address_id = ua.id
);

commit;
