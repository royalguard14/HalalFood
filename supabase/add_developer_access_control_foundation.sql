-- HALAL Food
-- Developer/Super Admin backend authorization foundation.
-- This does NOT create an Auth account or store a password.

begin;

create table if not exists public.developer_access (
  user_id uuid primary key references auth.users(id) on delete cascade,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.developer_access enable row level security;

create or replace function public.is_developer()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.developer_access da
    where da.user_id = auth.uid()
  );
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'admin'::user_role
  )
  or public.is_developer();
$$;

drop policy if exists "Developers can view developer access" on public.developer_access;
create policy "Developers can view developer access"
on public.developer_access
for select to authenticated
using ((select public.is_developer()));

drop policy if exists "Admins can manage halal verifications" on public.halal_verifications;
create policy "Admins can manage halal verifications"
on public.halal_verifications
for all to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

drop policy if exists "Admins can update halal verification requests" on public.halal_verifications;
create policy "Admins can update halal verification requests"
on public.halal_verifications
for update to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

drop policy if exists "Admins can view halal verification requests" on public.halal_verifications;
create policy "Admins can view halal verification requests"
on public.halal_verifications
for select to authenticated
using ((select public.is_admin()));

drop policy if exists "Admins can create restaurants" on public.restaurants;
create policy "Admins can create restaurants"
on public.restaurants
for insert to authenticated
with check ((select public.is_admin()));

drop policy if exists "Admins can update restaurants" on public.restaurants;
create policy "Admins can update restaurants"
on public.restaurants
for update to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

drop policy if exists "Admins can view all restaurants" on public.restaurants;
create policy "Admins can view all restaurants"
on public.restaurants
for select to authenticated
using ((select public.is_admin()));

drop policy if exists "Developers can manage delivery pricing settings" on public.delivery_pricing_settings;
create policy "Developers can manage delivery pricing settings"
on public.delivery_pricing_settings
for all to authenticated
using ((select public.is_developer()))
with check ((select public.is_developer()));

alter table public.delivery_pricing_settings enable row level security;

commit;
