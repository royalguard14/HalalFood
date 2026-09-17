-- HALAL Food — Role Management Permissions v2
-- Developer: may manage all roles.
-- Admin: may manage Customer <-> Restaurant Owner only.
-- Admins and ordinary users cannot see Developer accounts.
-- Developer access is separate from profiles.role.

DROP POLICY IF EXISTS "Developers can manage developer access" ON public.developer_access;
CREATE POLICY "Developers can manage developer access"
ON public.developer_access
FOR ALL
TO authenticated
USING (public.is_developer())
WITH CHECK (public.is_developer());

DROP POLICY IF EXISTS "Developers can update user roles" ON public.profiles;
DROP POLICY IF EXISTS "Admins can update non-developer profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admins can update user roles" ON public.profiles;

CREATE POLICY "Admins can update non-developer profiles"
ON public.profiles
FOR UPDATE
TO authenticated
USING (
  public.is_admin()
  AND NOT EXISTS (
    SELECT 1 FROM public.developer_access da
    WHERE da.user_id = profiles.id
  )
)
WITH CHECK (
  public.is_admin()
  AND NOT EXISTS (
    SELECT 1 FROM public.developer_access da
    WHERE da.user_id = profiles.id
  )
);

CREATE POLICY "Developers can update all profiles"
ON public.profiles
FOR UPDATE
TO authenticated
USING (public.is_developer())
WITH CHECK (public.is_developer());

DROP POLICY IF EXISTS "Admins and developers can view non-developer profiles" ON public.profiles;
DROP POLICY IF EXISTS "Authenticated users can view non-developer profiles" ON public.profiles;
CREATE POLICY "Authenticated users can view non-developer profiles"
ON public.profiles
FOR SELECT
TO authenticated
USING (
  public.is_developer()
  OR NOT EXISTS (
    SELECT 1 FROM public.developer_access da
    WHERE da.user_id = profiles.id
  )
);

CREATE OR REPLACE FUNCTION public.enforce_role_management_rules()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
BEGIN
  IF OLD.role IS DISTINCT FROM NEW.role THEN
    IF public.is_developer() THEN
      RETURN NEW;
    END IF;

    IF public.is_admin()
       AND NOT EXISTS (
         SELECT 1 FROM public.developer_access da
         WHERE da.user_id = OLD.id
       )
       AND OLD.role IN ('customer'::user_role, 'restaurant_owner'::user_role)
       AND NEW.role IN ('customer'::user_role, 'restaurant_owner'::user_role) THEN
      RETURN NEW;
    END IF;

    RAISE EXCEPTION 'Only a Developer can assign this role';
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS enforce_role_management_rules ON public.profiles;
CREATE TRIGGER enforce_role_management_rules
BEFORE UPDATE OF role ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.enforce_role_management_rules();

REVOKE ALL ON FUNCTION public.enforce_role_management_rules() FROM PUBLIC;
