-- Admin access for restaurant menu management.
-- Run this once in the Supabase SQL Editor.

ALTER TABLE public.menu_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menu_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menu_item_categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view all menu categories" ON public.menu_categories;
CREATE POLICY "Admins can view all menu categories"
ON public.menu_categories
FOR SELECT
TO authenticated
USING (public.is_admin());

DROP POLICY IF EXISTS "Admins can insert menu categories" ON public.menu_categories;
CREATE POLICY "Admins can insert menu categories"
ON public.menu_categories
FOR INSERT
TO authenticated
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins can update menu categories" ON public.menu_categories;
CREATE POLICY "Admins can update menu categories"
ON public.menu_categories
FOR UPDATE
TO authenticated
USING (public.is_admin())
WITH CHECK (true);

DROP POLICY IF EXISTS "Admins can delete menu categories" ON public.menu_categories;
CREATE POLICY "Admins can delete menu categories"
ON public.menu_categories
FOR DELETE
TO authenticated
USING (public.is_admin());

DROP POLICY IF EXISTS "Admins can view all menu items" ON public.menu_items;
CREATE POLICY "Admins can view all menu items"
ON public.menu_items
FOR SELECT
TO authenticated
USING (public.is_admin());

DROP POLICY IF EXISTS "Admins can insert menu items" ON public.menu_items;
CREATE POLICY "Admins can insert menu items"
ON public.menu_items
FOR INSERT
TO authenticated
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins can update menu items" ON public.menu_items;
CREATE POLICY "Admins can update menu items"
ON public.menu_items
FOR UPDATE
TO authenticated
USING (public.is_admin())
WITH CHECK (true);

DROP POLICY IF EXISTS "Admins can delete menu items" ON public.menu_items;
CREATE POLICY "Admins can delete menu items"
ON public.menu_items
FOR DELETE
TO authenticated
USING (public.is_admin());

DROP POLICY IF EXISTS "Admins can view all menu item categories" ON public.menu_item_categories;
CREATE POLICY "Admins can view all menu item categories"
ON public.menu_item_categories
FOR SELECT
TO authenticated
USING (public.is_admin());

DROP POLICY IF EXISTS "Admins can insert menu item categories" ON public.menu_item_categories;
CREATE POLICY "Admins can insert menu item categories"
ON public.menu_item_categories
FOR INSERT
TO authenticated
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins can update menu item categories" ON public.menu_item_categories;
CREATE POLICY "Admins can update menu item categories"
ON public.menu_item_categories
FOR UPDATE
TO authenticated
USING (public.is_admin())
WITH CHECK (true);

DROP POLICY IF EXISTS "Admins can delete menu item categories" ON public.menu_item_categories;
CREATE POLICY "Admins can delete menu item categories"
ON public.menu_item_categories
FOR DELETE
TO authenticated
USING (public.is_admin());
