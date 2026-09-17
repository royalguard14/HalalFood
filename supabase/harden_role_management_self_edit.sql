-- HALAL Food
-- Role management hardening: fixed platform roles and self-role protection.
-- Applied to Supabase project taltqnxhivpfwjqlvxnt on 2026-09-17.

-- Platform roles are:
-- customer, restaurant_owner, admin, developer, driver
-- Verifier is intentionally not part of the role model.

create or replace function public.enforce_role_management_rules()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$
begin
  if old.role is distinct from new.role then
    -- Nobody may change their own role, including Admin and Developer.
    if auth.uid() = old.id then
      raise exception 'You cannot change your own role';
    end if;

    -- Developer may assign any supported role to another account.
    if public.is_developer() then
      return new;
    end if;

    -- Admin may manage Customer, Restaurant Owner and Driver only.
    if public.is_admin()
       and not exists (
         select 1 from public.developer_access da
         where da.user_id = old.id
       )
       and old.role in ('customer'::user_role, 'restaurant_owner'::user_role)
       and new.role in (
         'customer'::user_role,
         'restaurant_owner'::user_role,
         'driver'::user_role
       ) then
      return new;
    end if;

    raise exception 'Only a Developer can assign this role';
  end if;

  return new;
end;
$function$;

revoke all on function public.enforce_role_management_rules() from public;
