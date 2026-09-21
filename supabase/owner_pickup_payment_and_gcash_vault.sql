-- Owner Pickup payment recording + GCash Vault
-- Applied to Supabase project taltqnxhivpfwjqlvxnt.

alter table public.payments
  add column if not exists paid_at timestamptz;

create table if not exists public.owner_gcash_cashouts (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  amount numeric not null check (amount > 0),
  notes text,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

alter table public.owner_gcash_cashouts enable row level security;

drop policy if exists "Restaurant owners can view own GCash cashouts" on public.owner_gcash_cashouts;
create policy "Restaurant owners can view own GCash cashouts"
on public.owner_gcash_cashouts
for select to authenticated
using (
  exists (
    select 1 from public.restaurants r
    where r.id = owner_gcash_cashouts.restaurant_id
      and r.owner_id = (select auth.uid())
  )
);

grant select on public.owner_gcash_cashouts to authenticated;

drop policy if exists "Restaurant owners can view own payment records" on public.payments;
create policy "Restaurant owners can view own payment records"
on public.payments
for select to authenticated
using (
  exists (
    select 1
    from public.orders o
    join public.restaurants r on r.id = o.restaurant_id
    where o.id = payments.order_id
      and r.owner_id = (select auth.uid())
  )
);

create or replace function public.record_owner_pickup_payment(
  p_order_id uuid,
  p_stage text,
  p_amount numeric,
  p_reference text default null,
  p_payment_method text default 'cash_on_delivery'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders%rowtype;
  v_existing_payment public.payments%rowtype;
  v_paid numeric := 0;
  v_new_total numeric;
  v_remaining numeric;
begin
  if (select auth.uid()) is null then raise exception 'Authentication required.'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Payment amount must be greater than zero.'; end if;

  select o.* into v_order
  from public.orders o
  join public.restaurants r on r.id = o.restaurant_id
  where o.id = p_order_id
    and r.owner_id = (select auth.uid())
    and o.fulfillment_type = 'pickup'
  for update;

  if not found then raise exception 'Pickup order not found or not owned by this restaurant.'; end if;

  select coalesce(sum(p.amount), 0) into v_paid
  from public.payments p
  where p.order_id = p_order_id and p.status = 'paid';

  if p_stage = 'downpayment' then
    if v_order.status <> 'pending' then raise exception 'Downpayment can only be confirmed while the order is awaiting confirmation.'; end if;
    if v_order.pickup_downpayment_status <> 'receipt_submitted' then raise exception 'The pickup receipt is not awaiting confirmation.'; end if;
    if p_amount > v_order.total_amount + 0.005 then
      raise exception 'Downpayment cannot exceed the order total of ₱%.', to_char(v_order.total_amount, 'FM999999990.00');
    end if;

    select p.* into v_existing_payment
    from public.payments p
    where p.order_id = p_order_id
      and p.status = 'pending'
      and p.payment_method = 'online'
    order by p.created_at asc
    limit 1
    for update;

    if not found then raise exception 'Pending pickup downpayment payment record not found.'; end if;

    update public.payments
    set amount = p_amount,
        payment_method = 'gcash',
        status = 'paid',
        transaction_reference = nullif(trim(coalesce(p_reference, '')), ''),
        paid_at = now(),
        updated_at = now()
    where id = v_existing_payment.id;

    update public.orders
    set pickup_downpayment_status = 'paid',
        pickup_downpayment_amount = p_amount,
        pickup_downpayment_percent = case when v_order.total_amount > 0 then round((p_amount / v_order.total_amount) * 100, 2) else 100 end,
        status = 'confirmed',
        payment_status = case
          when p_amount >= v_order.total_amount - 0.005 then 'paid'::public.payment_status
          else 'pending'::public.payment_status
        end,
        updated_at = now()
    where id = p_order_id;

    v_new_total := v_paid + p_amount;
    v_remaining := greatest(v_order.total_amount - v_new_total, 0);

  elsif p_stage = 'final' then
    if v_order.status <> 'ready' then raise exception 'Final payment can only be recorded when the order is Ready to Pick Up.'; end if;
    if p_payment_method <> 'cash_on_delivery' then raise exception 'Final pickup payment must be cash.'; end if;

    v_new_total := v_paid + p_amount;
    v_remaining := greatest(v_order.total_amount - v_paid, 0);

    if abs(p_amount - v_remaining) > 0.005 then
      raise exception 'Payment must be exactly the remaining balance of ₱%.', to_char(v_remaining, 'FM999999990.00');
    end if;

    insert into public.payments (order_id,customer_id,amount,payment_method,status,paid_at,notes)
    values (
      p_order_id,
      v_order.customer_id,
      p_amount,
      'cash_on_delivery'::public.payment_method,
      'paid'::public.payment_status,
      now(),
      'Pickup final cash payment'
    );

    update public.orders
    set payment_status = 'paid', updated_at = now()
    where id = p_order_id;

    v_remaining := 0;
  else
    raise exception 'Invalid pickup payment stage.';
  end if;

  return jsonb_build_object('order_id',p_order_id,'stage',p_stage,'paid_total',v_new_total,'order_total',v_order.total_amount,'remaining',v_remaining);
end;
$$;
revoke execute on function public.record_owner_pickup_payment(uuid,text,numeric,text,text) from public, anon;
grant execute on function public.record_owner_pickup_payment(uuid,text,numeric,text,text) to authenticated;

create or replace function public.record_owner_gcash_cashout(
  p_restaurant_id uuid,
  p_amount numeric,
  p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_available numeric;
  v_cashout_id uuid;
begin
  if (select auth.uid()) is null then raise exception 'Authentication required.'; end if;
  if not exists (
    select 1 from public.restaurants r
    where r.id = p_restaurant_id and r.owner_id = (select auth.uid())
  ) then raise exception 'Restaurant not found or not owned by this account.'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Cashout amount must be greater than zero.'; end if;

  select
    coalesce((
      select sum(p.amount) from public.payments p
      join public.orders o on o.id = p.order_id
      where o.restaurant_id = p_restaurant_id and p.status = 'paid' and p.payment_method = 'gcash'
    ),0)
    -
    coalesce((
      select sum(c.amount) from public.owner_gcash_cashouts c
      where c.restaurant_id = p_restaurant_id
    ),0)
  into v_available;

  if p_amount > v_available + 0.005 then
    raise exception 'Cashout exceeds available GCash balance of ₱%.', to_char(greatest(v_available,0),'FM999999990.00');
  end if;

  insert into public.owner_gcash_cashouts (restaurant_id,amount,notes,created_by)
  values (p_restaurant_id,p_amount,nullif(trim(coalesce(p_notes,'')),''),(select auth.uid()))
  returning id into v_cashout_id;

  return jsonb_build_object('id',v_cashout_id,'amount',p_amount,'balance',v_available-p_amount);
end;
$$;

revoke execute on function public.record_owner_gcash_cashout(uuid,numeric,text) from public, anon;
grant execute on function public.record_owner_gcash_cashout(uuid,numeric,text) to authenticated;

create index if not exists owner_gcash_cashouts_restaurant_created_idx
  on public.owner_gcash_cashouts (restaurant_id, created_at desc);

create index if not exists payments_order_status_method_idx
  on public.payments (order_id, status, payment_method);
