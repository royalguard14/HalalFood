-- HALAL Food SaaS subscription payment workflow
-- Run this migration in Supabase SQL Editor before testing the new owner flow.

-- 1) Each SaaS plan can have its own allowed payment methods.
create table if not exists public.subscription_payment_methods (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type text not null default 'other',
  account_name text,
  account_number text,
  instructions text,
  qr_code_url text,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.subscription_plan_payment_methods (
  plan_id uuid not null references public.subscription_plans(id) on delete cascade,
  payment_method_id uuid not null references public.subscription_payment_methods(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (plan_id, payment_method_id)
);

create index if not exists subscription_plan_payment_methods_method_idx
  on public.subscription_plan_payment_methods(payment_method_id);

-- 2) Pending is a real subscription state. It becomes active only after admin approval.
alter table public.restaurant_subscriptions drop constraint if exists restaurant_subscriptions_status_check;
alter table public.restaurant_subscriptions
  add constraint restaurant_subscriptions_status_check
  check (status in ('pending','trial','active','past_due','grace_period','suspended','cancelled','expired'));

-- 3) Payment proof is stored as a private Storage path, not a public URL.
alter table public.subscription_payments add column if not exists proof_path text;

alter table public.subscription_payments drop constraint if exists subscription_payments_status_check;
alter table public.subscription_payments
  add constraint subscription_payments_status_check
  check (status in ('pending','paid','failed','refunded','cancelled','rejected'));

-- 4) Storage bucket for payment screenshots. Keep it private.
insert into storage.buckets (id, name, public)
values ('subscription-payment-proofs', 'subscription-payment-proofs', false)
on conflict (id) do update set public = false;

-- 5) RLS
alter table public.subscription_payment_methods enable row level security;
alter table public.subscription_plan_payment_methods enable row level security;

-- Payment method definitions: admins manage them; authenticated users can see active ones.
drop policy if exists "Admins manage subscription payment methods" on public.subscription_payment_methods;
drop policy if exists "Authenticated users view active subscription payment methods" on public.subscription_payment_methods;

create policy "Admins manage subscription payment methods"
on public.subscription_payment_methods
for all to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "Authenticated users view active subscription payment methods"
on public.subscription_payment_methods
for select to authenticated
using (is_active = true);

-- Plan/method assignments: admins manage; authenticated users may read assignments.
drop policy if exists "Admins manage subscription plan payment methods" on public.subscription_plan_payment_methods;
drop policy if exists "Authenticated users view subscription plan payment methods" on public.subscription_plan_payment_methods;

create policy "Admins manage subscription plan payment methods"
on public.subscription_plan_payment_methods
for all to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "Authenticated users view subscription plan payment methods"
on public.subscription_plan_payment_methods
for select to authenticated
using (true);

-- Owners can submit ONLY pending subscriptions for their own restaurant.
drop policy if exists "Owners can insert their restaurant subscriptions" on public.restaurant_subscriptions;
drop policy if exists "Owners can submit pending restaurant subscriptions" on public.restaurant_subscriptions;

create policy "Owners can submit pending restaurant subscriptions"
on public.restaurant_subscriptions
for insert to authenticated
with check (
  status = 'pending'
  and exists (
    select 1 from public.restaurants r
    where r.id = restaurant_subscriptions.restaurant_id
      and r.owner_id = (select auth.uid())
  )
);

-- Owners can read their own subscriptions.
drop policy if exists "Owners can view their restaurant subscriptions" on public.restaurant_subscriptions;
create policy "Owners can view their restaurant subscriptions"
on public.restaurant_subscriptions
for select to authenticated
using (
  exists (
    select 1 from public.restaurants r
    where r.id = restaurant_subscriptions.restaurant_id
      and r.owner_id = (select auth.uid())
  )
);

-- Owners can submit their own pending payment records only.
drop policy if exists "Owners can insert subscription payments" on public.subscription_payments;
drop policy if exists "Owners can view their subscription payments" on public.subscription_payments;

create policy "Owners can insert subscription payments"
on public.subscription_payments
for insert to authenticated
with check (
  status = 'pending'
  and exists (
    select 1
    from public.restaurants r
    where r.id = subscription_payments.restaurant_id
      and r.owner_id = (select auth.uid())
  )
  and exists (
    select 1
    from public.restaurant_subscriptions rs
    where rs.id = subscription_payments.subscription_id
      and rs.restaurant_id = subscription_payments.restaurant_id
      and rs.status = 'pending'
  )
);

create policy "Owners can view their subscription payments"
on public.subscription_payments
for select to authenticated
using (
  exists (
    select 1 from public.restaurants r
    where r.id = subscription_payments.restaurant_id
      and r.owner_id = (select auth.uid())
  )
);

-- 6) Storage RLS. Owner path convention: <restaurant_id>/<uuid>.jpg
-- Admins can read/manage proofs; owners can upload/read only inside their restaurant folder.
drop policy if exists "Owners upload subscription payment proofs" on storage.objects;
drop policy if exists "Owners view subscription payment proofs" on storage.objects;
drop policy if exists "Admins manage subscription payment proofs" on storage.objects;

create policy "Owners upload subscription payment proofs"
on storage.objects
for insert to authenticated
with check (
  bucket_id = 'subscription-payment-proofs'
  and exists (
    select 1 from public.restaurants r
    where r.id::text = (storage.foldername(name))[1]
      and r.owner_id = (select auth.uid())
  )
);

create policy "Owners view subscription payment proofs"
on storage.objects
for select to authenticated
using (
  bucket_id = 'subscription-payment-proofs'
  and exists (
    select 1 from public.restaurants r
    where r.id::text = (storage.foldername(name))[1]
      and r.owner_id = (select auth.uid())
  )
);

create policy "Admins manage subscription payment proofs"
on storage.objects
for all to authenticated
using (bucket_id = 'subscription-payment-proofs' and public.is_admin())
with check (bucket_id = 'subscription-payment-proofs' and public.is_admin());

-- 7) Keep the owner from creating an already-active subscription through the normal table API.
-- Admins retain their existing full CRUD policies from saas_subscriptions.sql.
