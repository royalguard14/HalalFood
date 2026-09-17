-- Applied to Supabase project taltqnxhivpfwjqlvxnt
-- 2026-09-17
--
-- Role model: admin, restaurant_owner, customer, developer, driver.
-- Developer privilege remains separately enforced through developer_access.

-- user_role is recreated because PostgreSQL does not support removing an
-- existing enum value with ALTER TYPE. No profiles currently used verifier.
DROP POLICY IF EXISTS "Authenticated users can view non-developer profiles" ON public.profiles;
DROP TRIGGER IF EXISTS enforce_role_management_rules ON public.profiles;
ALTER TABLE public.profiles ALTER COLUMN role DROP DEFAULT;
ALTER TYPE public.user_role RENAME TO user_role_legacy;
CREATE TYPE public.user_role AS ENUM ('customer', 'restaurant_owner', 'admin', 'developer', 'driver');
ALTER TABLE public.profiles
  ALTER COLUMN role TYPE public.user_role
  USING role::text::public.user_role;
ALTER TABLE public.profiles
  ALTER COLUMN role SET DEFAULT 'customer'::public.user_role;
DROP TYPE public.user_role_legacy;

CREATE TRIGGER enforce_role_management_rules
BEFORE UPDATE OF role ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.enforce_role_management_rules();

CREATE POLICY "Authenticated users can view non-developer profiles"
ON public.profiles
FOR SELECT
TO authenticated
USING (
  public.is_developer()
  OR NOT EXISTS (
    SELECT 1
    FROM public.developer_access da
    WHERE da.user_id = profiles.id
  )
  AND profiles.role <> 'developer'::public.user_role
);

-- Zear Developer account.
UPDATE public.profiles
SET role = 'developer'::public.user_role,
    updated_at = now()
WHERE id = '83ac0256-1237-4617-9647-50592f714b0b';

INSERT INTO public.developer_access (user_id, notes)
VALUES (
  '83ac0256-1237-4617-9647-50592f714b0b',
  'Primary developer / super admin account'
)
ON CONFLICT (user_id) DO UPDATE SET notes = EXCLUDED.notes;
