-- HALAL Food SaaS - Restaurant subscriptions
-- Run in Supabase SQL Editor.
-- This is for RESTAURANT SaaS billing, not customer order payments.

create table if not exists public.subscription_plans (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text,
  monthly_price numeric(12,2) not null default 0,
  annual_price numeric(12,2),
  is_active boolean not null default true,
  sort_order integer not null default 0,
  features jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint subscription_plans_price_check check (monthly_price >= 0),
  constraint subscription_plans_annual_check check (annual_price is null or annual_price >= 0)
);

create table if not exists public.restaurant_subscriptions (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  plan_id uuid not null references public.subscription_plans(id),
  status text not null default 'active',
  billing_cycle text not null default 'monthly',
  started_at timestamptz not null default now(),
  current_period_start timestamptz not null default now(),
  current_period_end timestamptz not null,
  next_billing_at timestamptz,
  grace_period_end timestamptz,
  cancelled_at timestamptz,
  suspended_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint restaurant_subscriptions_status_check check (status in ('trial','active','past_due','grace_period','suspended','cancelled','expired')),
  constraint restaurant_subscriptions_cycle_check check (billing_cycle in ('monthly','annual'))
);

create unique index if not exists restaurant_subscriptions_one_active_idx
  on public.restaurant_subscriptions(restaurant_id)
  where status in ('trial','active','past_due','grace_period');

create index if not exists restaurant_subscriptions_restaurant_idx on public.restaurant_subscriptions(restaurant_id);
create index if not exists restaurant_subscriptions_plan_idx on public.restaurant_subscriptions(plan_id);
create index if not exists restaurant_subscriptions_status_idx on public.restaurant_subscriptions(status);
create index if not exists restaurant_subscriptions_next_billing_idx on public.restaurant_subscriptions(next_billing_at);

create table if not exists public.subscription_payments (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references public.restaurant_subscriptions(id) on delete cascade,
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  amount numeric(12,2) not null default 0,
  currency text not null default 'PHP',
  status text not null default 'pending',
  payment_method text,
  transaction_reference text,
  billing_period_start timestamptz,
  billing_period_end timestamptz,
  paid_at timestamptz,
  refunded_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint subscription_payments_status_check check (status in ('pending','paid','failed','refunded','cancelled')),
  constraint subscription_payments_amount_check check (amount >= 0)
);

create index if not exists subscription_payments_subscription_idx on public.subscription_payments(subscription_id);
create index if not exists subscription_payments_restaurant_idx on public.subscription_payments(restaurant_id);
create index if not exists subscription_payments_status_idx on public.subscription_payments(status);
create index if not exists subscription_payments_created_at_idx on public.subscription_payments(created_at desc);

alter table public.subscription_plans enable row level security;
alter table public.restaurant_subscriptions enable row level security;
alter table public.subscription_payments enable row level security;

drop policy if exists "Admins can view subscription plans" on public.subscription_plans;
drop policy if exists "Admins can insert subscription plans" on public.subscription_plans;
drop policy if exists "Admins can update subscription plans" on public.subscription_plans;
drop policy if exists "Admins can delete subscription plans" on public.subscription_plans;

create policy "Admins can view subscription plans" on public.subscription_plans for select to authenticated using (public.is_admin());
create policy "Admins can insert subscription plans" on public.subscription_plans for insert to authenticated with check (public.is_admin());
create policy "Admins can update subscription plans" on public.subscription_plans for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "Admins can delete subscription plans" on public.subscription_plans for delete to authenticated using (public.is_admin());

drop policy if exists "Admins can view restaurant subscriptions" on public.restaurant_subscriptions;
drop policy if exists "Admins can insert restaurant subscriptions" on public.restaurant_subscriptions;
drop policy if exists "Admins can update restaurant subscriptions" on public.restaurant_subscriptions;
drop policy if exists "Admins can delete restaurant subscriptions" on public.restaurant_subscriptions;

create policy "Admins can view restaurant subscriptions" on public.restaurant_subscriptions for select to authenticated using (public.is_admin());
create policy "Admins can insert restaurant subscriptions" on public.restaurant_subscriptions for insert to authenticated with check (public.is_admin());
create policy "Admins can update restaurant subscriptions" on public.restaurant_subscriptions for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "Admins can delete restaurant subscriptions" on public.restaurant_subscriptions for delete to authenticated using (public.is_admin());

drop policy if exists "Admins can view subscription payments" on public.subscription_payments;
drop policy if exists "Admins can insert subscription payments" on public.subscription_payments;
drop policy if exists "Admins can update subscription payments" on public.subscription_payments;
drop policy if exists "Admins can delete subscription payments" on public.subscription_payments;

create policy "Admins can view subscription payments" on public.subscription_payments for select to authenticated using (public.is_admin());
create policy "Admins can insert subscription payments" on public.subscription_payments for insert to authenticated with check (public.is_admin());
create policy "Admins can update subscription payments" on public.subscription_payments for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "Admins can delete subscription payments" on public.subscription_payments for delete to authenticated using (public.is_admin());

create or replace function public.set_subscription_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists subscription_plans_set_updated_at on public.subscription_plans;
create trigger subscription_plans_set_updated_at before update on public.subscription_plans for each row execute function public.set_subscription_updated_at();

drop trigger if exists restaurant_subscriptions_set_updated_at on public.restaurant_subscriptions;
create trigger restaurant_subscriptions_set_updated_at before update on public.restaurant_subscriptions for each row execute function public.set_subscription_updated_at();

drop trigger if exists subscription_payments_set_updated_at on public.subscription_payments;
create trigger subscription_payments_set_updated_at before update on public.subscription_payments for each row execute function public.set_subscription_updated_at();

insert into public.subscription_plans (name, description, monthly_price, annual_price, sort_order, features)
values
  ('Starter', 'For small restaurants getting started on HALAL Food.', 499, 4990, 1, '["Restaurant profile","Menu management","Order management","Basic analytics"]'::jsonb),
  ('Pro', 'For growing restaurants that need more visibility and tools.', 999, 9990, 2, '["Everything in Starter","Featured placement","Promotions","Advanced analytics"]'::jsonb),
  ('Business', 'For established restaurants with higher operational needs.', 1999, 19990, 3, '["Everything in Pro","Priority support","Advanced reporting","Multiple staff accounts"]'::jsonb)
on conflict (name) do nothing;
