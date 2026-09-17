-- HALAL Food SaaS - Owner subscription submission hardening
-- Run in Supabase SQL Editor before testing the hardened owner flow.

-- 1) Prevent more than one pending subscription per restaurant at database level.
-- Active/trial/past_due/grace_period already have their own unique index in saas_subscriptions.sql.
create unique index if not exists restaurant_subscriptions_one_pending_idx
  on public.restaurant_subscriptions(restaurant_id)
  where status = 'pending';

-- 2) Owners may delete only their own pending subscription rows.
-- This is used only for best-effort rollback when proof upload or payment-record creation fails.
drop policy if exists "Owners can delete their pending restaurant subscriptions"
  on public.restaurant_subscriptions;

create policy "Owners can delete their pending restaurant subscriptions"
on public.restaurant_subscriptions
for delete to authenticated
using (
  status = 'pending'
  and exists (
    select 1
    from public.restaurants r
    where r.id = restaurant_subscriptions.restaurant_id
      and r.owner_id = (select auth.uid())
  )
);

-- 3) Owners may delete only payment-proof files inside their own restaurant folder.
-- This is also best-effort rollback for a proof upload that succeeded before
-- the subscription_payments insert failed.
drop policy if exists "Owners delete subscription payment proofs"
  on storage.objects;

create policy "Owners delete subscription payment proofs"
on storage.objects
for delete to authenticated
using (
  bucket_id = 'subscription-payment-proofs'
  and exists (
    select 1
    from public.restaurants r
    where r.id::text = (storage.foldername(name))[1]
      and r.owner_id = (select auth.uid())
  )
);
