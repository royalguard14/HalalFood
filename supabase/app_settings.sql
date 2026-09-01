-- HALAL Food: Admin Platform Settings
-- Run this once in Supabase SQL Editor.

create table if not exists public.app_settings (
  id boolean primary key default true,
  maintenance_mode boolean not null default false,
  accept_new_orders boolean not null default true,
  allow_customer_registration boolean not null default true,
  allow_owner_restaurant_submission boolean not null default true,
  customer_notifications boolean not null default true,
  owner_notifications boolean not null default true,
  updated_at timestamptz not null default now(),
  constraint app_settings_singleton check (id = true)
);

insert into public.app_settings (id)
values (true)
on conflict (id) do nothing;

alter table public.app_settings enable row level security;

drop policy if exists "Admins can view app settings" on public.app_settings;
drop policy if exists "Admins can update app settings" on public.app_settings;

create policy "Admins can view app settings"
on public.app_settings
for select
to authenticated
using (public.is_admin());

create policy "Admins can update app settings"
on public.app_settings
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create or replace function public.set_app_settings_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists app_settings_updated_at on public.app_settings;
create trigger app_settings_updated_at
before update on public.app_settings
for each row execute function public.set_app_settings_updated_at();
