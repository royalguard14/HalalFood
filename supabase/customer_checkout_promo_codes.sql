-- Customer checkout promo/coupon foundation.
-- Global Admin promos: restaurant_id IS NULL.
-- Restaurant Owner promos: restaurant_id = the restaurant UUID.
-- A customer can redeem each promo code only once.

alter table public.orders
  add column if not exists promo_code_id uuid null references public.promo_codes(id) on delete set null,
  add column if not exists promo_discount numeric not null default 0;

alter table public.orders
  add constraint orders_promo_discount_nonnegative
  check (promo_discount >= 0);

create table if not exists public.promo_redemptions (
  id uuid primary key default gen_random_uuid(),
  promo_code_id uuid not null references public.promo_codes(id) on delete cascade,
  customer_id uuid not null references auth.users(id) on delete cascade,
  order_id uuid not null unique references public.orders(id) on delete cascade,
  discount_amount numeric not null check (discount_amount >= 0),
  redeemed_at timestamptz not null default now(),
  unique (promo_code_id, customer_id)
);

create index if not exists promo_codes_restaurant_active_idx
  on public.promo_codes (restaurant_id, is_active);

create index if not exists promo_redemptions_promo_code_idx
  on public.promo_redemptions (promo_code_id);

create index if not exists promo_redemptions_customer_idx
  on public.promo_redemptions (customer_id);

alter table public.promo_redemptions enable row level security;

drop policy if exists "Customers can view own promo redemptions" on public.promo_redemptions;
create policy "Customers can view own promo redemptions"
on public.promo_redemptions
for select
to authenticated
using ((select auth.uid()) = customer_id);

drop policy if exists "Admins can view promo redemptions" on public.promo_redemptions;
create policy "Admins can view promo redemptions"
on public.promo_redemptions
for select
to authenticated
using ((select is_admin()));

drop policy if exists "Owners can view own restaurant promo redemptions" on public.promo_redemptions;
create policy "Owners can view own restaurant promo redemptions"
on public.promo_redemptions
for select
to authenticated
using (
  exists (
    select 1
    from public.promo_codes pc
    join public.restaurants r on r.id = pc.restaurant_id
    where pc.id = promo_redemptions.promo_code_id
      and r.owner_id = (select auth.uid())
  )
);

drop policy if exists "Customers can view applicable promo codes" on public.promo_codes;
create policy "Customers can view applicable promo codes"
on public.promo_codes
for select
to authenticated
using (
  is_active = true
  and (restaurant_id is null or exists (
    select 1
    from public.restaurants r
    where r.id = promo_codes.restaurant_id
      and r.is_active = true
  ))
);

create or replace function public.claim_promo_code(
  p_order_id uuid,
  p_code text
)
returns table (
  promo_code_id uuid,
  discount_amount numeric
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_order public.orders%rowtype;
  v_promo public.promo_codes%rowtype;
  v_discount numeric;
  v_usage_count integer;
begin
  if v_user_id is null then
    raise exception 'User is not authenticated.';
  end if;

  select *
  into v_order
  from public.orders
  where id = p_order_id
    and customer_id = v_user_id
  for update;

  if not found then
    raise exception 'Order not found.';
  end if;

  if v_order.promo_code_id is not null then
    raise exception 'A promo code has already been applied to this order.';
  end if;

  select *
  into v_promo
  from public.promo_codes
  where upper(code) = upper(trim(p_code))
    and is_active = true
    and (restaurant_id is null or restaurant_id = v_order.restaurant_id)
  for update;

  if not found then
    raise exception 'Promo code is not available for this restaurant.';
  end if;

  if v_promo.starts_at is not null and now() < v_promo.starts_at then
    raise exception 'This promo code is not active yet.';
  end if;

  if v_promo.ends_at is not null and now() > v_promo.ends_at then
    raise exception 'This promo code has expired.';
  end if;

  if v_order.subtotal < coalesce(v_promo.minimum_order, 0) then
    raise exception 'Minimum order for this promo is %.', v_promo.minimum_order;
  end if;

  select count(*)::integer
  into v_usage_count
  from public.promo_redemptions pr
  where pr.promo_code_id = v_promo.id;

  if v_promo.usage_limit is not null and v_usage_count >= v_promo.usage_limit then
    raise exception 'This promo code has reached its usage limit.';
  end if;

  if exists (
    select 1
    from public.promo_redemptions pr
    where pr.promo_code_id = v_promo.id
      and pr.customer_id = v_user_id
  ) then
    raise exception 'You have already used this promo code.';
  end if;

  if lower(v_promo.discount_type) in ('percentage', 'percent') then
    v_discount := round(v_order.subtotal * (v_promo.discount_value / 100), 2);
  elsif lower(v_promo.discount_type) in ('fixed', 'amount') then
    v_discount := v_promo.discount_value;
  else
    raise exception 'Unsupported promo discount type.';
  end if;

  v_discount := greatest(0, least(v_discount, v_order.subtotal));

  if v_promo.maximum_discount is not null then
    v_discount := least(v_discount, v_promo.maximum_discount);
  end if;

  v_discount := round(greatest(0, least(v_discount, v_order.subtotal)), 2);

  insert into public.promo_redemptions (
    promo_code_id,
    customer_id,
    order_id,
    discount_amount
  )
  values (
    v_promo.id,
    v_user_id,
    v_order.id,
    v_discount
  );

  -- Mark this trusted transaction so the customer-order UPDATE guard allows
  -- only the promo fields changed by this SECURITY DEFINER workflow.
  perform set_config('app.claim_promo_code', 'true', true);

  update public.orders o
  set promo_code_id = v_promo.id,
      promo_discount = v_discount,
      total_amount = greatest(0, o.subtotal + o.delivery_fee - v_discount),
      updated_at = now()
  where o.id = v_order.id;

  return query
  select v_promo.id, v_discount;
end;
$$;

revoke all on function public.claim_promo_code(uuid, text) from public, anon;
grant execute on function public.claim_promo_code(uuid, text) to authenticated;

create or replace function public.sync_promo_usage_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    update public.promo_codes
    set usage_count = (
      select count(*) from public.promo_redemptions
      where promo_code_id = new.promo_code_id
    ),
    updated_at = now()
    where id = new.promo_code_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.promo_codes
    set usage_count = (
      select count(*) from public.promo_redemptions
      where promo_code_id = old.promo_code_id
    ),
    updated_at = now()
    where id = old.promo_code_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists promo_redemption_usage_count_trigger on public.promo_redemptions;
create trigger promo_redemption_usage_count_trigger
after insert or delete on public.promo_redemptions
for each row execute function public.sync_promo_usage_count();

revoke all on function public.sync_promo_usage_count() from public, anon, authenticated;
