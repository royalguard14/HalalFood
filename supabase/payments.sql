-- HALAL Food - Payments / Transactions
-- Run this in Supabase SQL Editor.

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid,
  customer_id uuid,
  amount numeric(12,2) not null default 0,
  payment_method text not null default 'cash_on_delivery',
  status text not null default 'pending',
  transaction_reference text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint payments_status_check check (status in ('pending','paid','failed','refunded','cancelled')),
  constraint payments_method_check check (payment_method in ('cash_on_delivery','gcash','card','online'))
);

create index if not exists payments_order_id_idx on public.payments(order_id);
create index if not exists payments_customer_id_idx on public.payments(customer_id);
create index if not exists payments_status_idx on public.payments(status);
create index if not exists payments_created_at_idx on public.payments(created_at desc);

alter table public.payments enable row level security;

 drop policy if exists "Admins can view payments" on public.payments;
 drop policy if exists "Admins can insert payments" on public.payments;
 drop policy if exists "Admins can update payments" on public.payments;
 drop policy if exists "Admins can delete payments" on public.payments;

create policy "Admins can view payments"
  on public.payments for select
  to authenticated
  using (public.is_admin());

create policy "Admins can insert payments"
  on public.payments for insert
  to authenticated
  with check (public.is_admin());

create policy "Admins can update payments"
  on public.payments for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "Admins can delete payments"
  on public.payments for delete
  to authenticated
  using (public.is_admin());

create or replace function public.set_payments_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists payments_set_updated_at on public.payments;
create trigger payments_set_updated_at
before update on public.payments
for each row execute function public.set_payments_updated_at();
