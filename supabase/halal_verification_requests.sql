-- Owner halal verification request policies.
-- Run this once in Supabase SQL Editor.
-- The owner can submit a request only for a restaurant they own.
-- Admins can review and decide on requests.

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
