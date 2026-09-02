-- HALAL Food customer subscription visibility
-- Run this in Supabase SQL Editor once.
-- Customers may see only restaurants with a currently active subscription.

alter table public.restaurant_subscriptions enable row level security;

drop policy if exists "Customers can view active restaurant subscriptions" on public.restaurant_subscriptions;

create policy "Customers can view active restaurant subscriptions"
on public.restaurant_subscriptions
for select to authenticated
using (
  status = 'active'
  and current_period_end > now()
);
