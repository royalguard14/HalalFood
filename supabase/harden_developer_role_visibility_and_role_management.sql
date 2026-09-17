-- Developer is the only role-management authority.
-- Admins must not be able to see Developer accounts or grant/revoke Developer access.

DROP POLICY IF EXISTS "Admins can update user roles" ON public.profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can view profiles" ON public.profiles;

CREATE POLICY "Developers can update user roles"
ON public.profiles
FOR UPDATE
TO authenticated
USING (public.is_developer())
WITH CHECK (public.is_developer());

CREATE POLICY "Admins and developers can view non-developer profiles"
ON public.profiles
FOR SELECT
TO authenticated
USING (
  public.is_developer()
  OR (
    public.is_admin()
    AND NOT EXISTS (
      SELECT 1
      FROM public.developer_access da
      WHERE da.user_id = profiles.id
    )
  )
  OR auth.uid() = profiles.id
);

-- developer_access remains protected by its existing Developer-only RLS policy.
