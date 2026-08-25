-- Owner restaurant submission support
-- Run this once in Supabase SQL Editor.
-- This allows a restaurant owner to see their own restaurant even while it is inactive/pending approval.

create policy "Restaurant owners can view own restaurants"
on public.restaurants
for select
to authenticated
using (auth.uid() = owner_id);

-- Owner submissions use owner_id = auth.uid(), is_active = false.
-- The existing insert policy should already allow this:
--   with check (auth.uid() = owner_id)
-- Admin can approve the submission by setting is_active = true from Restaurant Management.
