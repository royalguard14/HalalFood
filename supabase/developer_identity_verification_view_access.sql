-- Developer view-only access for personal identity verification records.
-- Approval/rejection remains Admin-only.

drop policy if exists "Admins and Developers can view identity verifications"
  on public.identity_verifications;

create policy "Admins and Developers can view identity verifications"
on public.identity_verifications
for select
to authenticated
using (
  public.is_admin()
  or public.is_developer()
);
