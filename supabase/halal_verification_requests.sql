-- Owner halal verification request support.
-- Run this once in Supabase SQL Editor.

alter table public.halal_verifications
  add column if not exists requested_status text;

alter table public.halal_verifications
  drop constraint if exists halal_verifications_requested_status_check;

alter table public.halal_verifications
  add constraint halal_verifications_requested_status_check
  check (requested_status is null or requested_status in ('muslim_owned', 'halal_verified', 'certified_halal'));

drop policy if exists "Owners can view own halal verification requests"
on public.halal_verifications;

create policy "Owners can view own halal verification requests"
on public.halal_verifications
for select
to authenticated
using (auth.uid() = submitted_by);

drop policy if exists "Owners can submit halal verification requests"
on public.halal_verifications;

create policy "Owners can submit halal verification requests"
on public.halal_verifications
for insert
to authenticated
with check (
  auth.uid() = submitted_by
  and exists (
    select 1
    from public.restaurants r
    where r.id = restaurant_id
      and r.owner_id = auth.uid()
      and r.halal_status = 'unverified'
  )
);

drop policy if exists "Admins can view halal verification requests"
on public.halal_verifications;

create policy "Admins can view halal verification requests"
on public.halal_verifications
for select
to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'admin'::user_role
  )
);

drop policy if exists "Admins can update halal verification requests"
on public.halal_verifications;

create policy "Admins can update halal verification requests"
on public.halal_verifications
for update
to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'admin'::user_role
  )
)
with check (
  exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'admin'::user_role
  )
);
