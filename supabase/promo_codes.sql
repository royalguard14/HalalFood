create table if not exists public.promo_codes (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  title text not null,
  description text,
  discount_type text not null check (discount_type in ('percentage','fixed')),
  discount_value numeric(12,2) not null check (discount_value > 0),
  minimum_order numeric(12,2) not null default 0 check (minimum_order >= 0),
  maximum_discount numeric(12,2),
  usage_limit integer,
  usage_count integer not null default 0 check (usage_count >= 0),
  starts_at timestamptz,
  ends_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.promo_codes enable row level security;

drop policy if exists "Admins can view promo codes" on public.promo_codes;
drop policy if exists "Admins can insert promo codes" on public.promo_codes;
drop policy if exists "Admins can update promo codes" on public.promo_codes;
drop policy if exists "Admins can delete promo codes" on public.promo_codes;

create policy "Admins can view promo codes"
on public.promo_codes for select to authenticated
using (public.is_admin());

create policy "Admins can insert promo codes"
on public.promo_codes for insert to authenticated
with check (public.is_admin());

create policy "Admins can update promo codes"
on public.promo_codes for update to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "Admins can delete promo codes"
on public.promo_codes for delete to authenticated
using (public.is_admin());

create or replace function public.set_promo_codes_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists promo_codes_updated_at on public.promo_codes;
create trigger promo_codes_updated_at
before update on public.promo_codes
for each row execute function public.set_promo_codes_updated_at();