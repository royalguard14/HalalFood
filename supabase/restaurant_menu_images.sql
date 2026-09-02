-- Restaurant and menu photos
-- Uses public image buckets so customer-facing restaurant/menu cards can load images directly.

insert into storage.buckets (id, name, public)
values
  ('restaurant-images', 'restaurant-images', true),
  ('menu-item-images', 'menu-item-images', true)
on conflict (id) do update set public = excluded.public;

-- Restaurant images: first folder is restaurant UUID.
drop policy if exists "Owners upload restaurant images" on storage.objects;
create policy "Owners upload restaurant images"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'restaurant-images'
  and exists (
    select 1 from public.restaurants r
    where r.id::text = (storage.foldername(objects.name))[1]
      and r.owner_id = (select auth.uid())
  )
);

drop policy if exists "Owners update restaurant images" on storage.objects;
create policy "Owners update restaurant images"
on storage.objects for update to authenticated
using (
  bucket_id = 'restaurant-images'
  and exists (
    select 1 from public.restaurants r
    where r.id::text = (storage.foldername(objects.name))[1]
      and r.owner_id = (select auth.uid())
  )
)
with check (
  bucket_id = 'restaurant-images'
  and exists (
    select 1 from public.restaurants r
    where r.id::text = (storage.foldername(objects.name))[1]
      and r.owner_id = (select auth.uid())
  )
);

drop policy if exists "Owners delete restaurant images" on storage.objects;
create policy "Owners delete restaurant images"
on storage.objects for delete to authenticated
using (
  bucket_id = 'restaurant-images'
  and exists (
    select 1 from public.restaurants r
    where r.id::text = (storage.foldername(objects.name))[1]
      and r.owner_id = (select auth.uid())
  )
);

-- Menu item images: first folder is restaurant UUID, second folder is item UUID.
drop policy if exists "Owners upload menu item images" on storage.objects;
create policy "Owners upload menu item images"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'menu-item-images'
  and exists (
    select 1
    from public.restaurants r
    where r.id::text = (storage.foldername(objects.name))[1]
      and r.owner_id = (select auth.uid())
  )
);

drop policy if exists "Owners update menu item images" on storage.objects;
create policy "Owners update menu item images"
on storage.objects for update to authenticated
using (
  bucket_id = 'menu-item-images'
  and exists (
    select 1
    from public.restaurants r
    where r.id::text = (storage.foldername(objects.name))[1]
      and r.owner_id = (select auth.uid())
  )
)
with check (
  bucket_id = 'menu-item-images'
  and exists (
    select 1
    from public.restaurants r
    where r.id::text = (storage.foldername(objects.name))[1]
      and r.owner_id = (select auth.uid())
  )
);

drop policy if exists "Owners delete menu item images" on storage.objects;
create policy "Owners delete menu item images"
on storage.objects for delete to authenticated
using (
  bucket_id = 'menu-item-images'
  and exists (
    select 1
    from public.restaurants r
    where r.id::text = (storage.foldername(objects.name))[1]
      and r.owner_id = (select auth.uid())
  )
);

-- Public read policies for customer-facing images.
drop policy if exists "Anyone can view restaurant images" on storage.objects;
create policy "Anyone can view restaurant images"
on storage.objects for select to public
using (bucket_id = 'restaurant-images');

drop policy if exists "Anyone can view menu item images" on storage.objects;
create policy "Anyone can view menu item images"
on storage.objects for select to public
using (bucket_id = 'menu-item-images');
