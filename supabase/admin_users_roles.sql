-- HALAL Food: Admin Users & Roles
-- Run once in Supabase SQL Editor.
-- Requires the existing public.is_admin() SECURITY DEFINER helper.

alter table public.profiles enable row level security;

 drop policy if exists "Admins can view all profiles" on public.profiles;
create policy "Admins can view all profiles"
on public.profiles
for select
to authenticated
using (public.is_admin());

 drop policy if exists "Admins can update user roles" on public.profiles;
create policy "Admins can update user roles"
on public.profiles
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());
