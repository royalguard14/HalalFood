-- Identity verification retention and Developer cleanup hardening
-- Applied to Supabase project taltqnxhivpfwjqlvxnt on 2026-09-18.

create unique index if not exists identity_verifications_one_approved_per_user_role_idx
on public.identity_verifications(user_id, role)
where status = 'approved';

drop policy if exists "Users can submit identity verification" on public.identity_verifications;

create policy "Users can submit identity verification"
on public.identity_verifications
for insert
to authenticated
with check (
  user_id = auth.uid()
  and role in ('customer', 'driver', 'restaurant_owner')
  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = identity_verifications.role
  )
  and status = 'pending'
  and reviewed_by is null
  and reviewed_at is null
  and not exists (
    select 1
    from public.identity_verifications approved
    where approved.user_id = auth.uid()
      and approved.role = identity_verifications.role
      and approved.status = 'approved'
  )
);

drop policy if exists "Users can delete own rejected identity verifications"
  on public.identity_verifications;

create policy "Users can delete own rejected identity verifications"
on public.identity_verifications
for delete
to authenticated
using (
  user_id = auth.uid()
  and status = 'rejected'
);

drop policy if exists "Admins and Developers can delete identity verifications"
  on public.identity_verifications;

create policy "Admins and Developers can delete identity verifications"
on public.identity_verifications
for delete
to authenticated
using (
  public.is_admin()
  or public.is_developer()
);

drop policy if exists "Admins and Developers can delete identity files"
  on storage.objects;

create policy "Admins and Developers can delete identity files"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'identity-verifications'
  and (public.is_admin() or public.is_developer())
);