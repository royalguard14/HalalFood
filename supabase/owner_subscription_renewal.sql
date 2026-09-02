-- Owner subscription renewal lifecycle
--
-- The owner app creates a NEW restaurant_subscriptions row when an
-- expired/cancelled subscription is submitted again. This keeps the full
-- subscription history intact instead of reactivating an old subscription.

-- Mark subscriptions as expired once their current period has ended.
-- Run this function from a scheduled Supabase job (for example, pg_cron)
-- so expired subscriptions are transitioned automatically.
create or replace function public.expire_restaurant_subscriptions()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  affected integer;
begin
  update public.restaurant_subscriptions
  set
    status = 'expired',
    updated_at = now()
  where status in ('active', 'trial', 'past_due', 'grace_period')
    and current_period_end is not null
    and current_period_end <= now();

  get diagnostics affected = row_count;
  return affected;
end;
$$;

revoke all on function public.expire_restaurant_subscriptions() from public;

-- Optional Supabase pg_cron setup:
-- 1. Enable the pg_cron extension in Supabase Dashboard > Database > Extensions.
-- 2. Then run the following once:
--
-- select cron.schedule(
--   'expire-halal-food-subscriptions',
--   '*/15 * * * *',
--   $$select public.expire_restaurant_subscriptions();$$
-- );
--
-- The owner flow is then:
-- active -> expired -> Subscribe Again -> pending -> admin approval -> active.
-- cancelled -> Subscribe Again -> pending -> admin approval -> active.
