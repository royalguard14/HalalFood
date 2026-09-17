-- Developer white-label branding/theme foundation.
-- Each deployment selects a brand_key through BRAND_KEY in .env.
-- Developers can manage brand configs; clients can read the active configuration.

create table if not exists public.brand_configs (
  brand_key text primary key,
  app_name text not null default 'HALAL Food',
  primary_color text not null default '#0B6B3A',
  secondary_color text not null default '#064B2A',
  accent_color text not null default '#D4A72C',
  background_color text not null default '#F8F9F7',
  surface_color text not null default '#FFFFFF',
  text_primary_color text not null default '#1A1A1A',
  text_secondary_color text not null default '#6B6B6B',
  border_color text not null default '#E5E5E5',
  updated_at timestamptz not null default now(),
  constraint brand_configs_brand_key_check check (brand_key ~ '^[a-z0-9][a-z0-9_-]{0,63}$'),
  constraint brand_configs_color_check check (
    primary_color ~ '^#[0-9A-Fa-f]{6}$' and
    secondary_color ~ '^#[0-9A-Fa-f]{6}$' and
    accent_color ~ '^#[0-9A-Fa-f]{6}$' and
    background_color ~ '^#[0-9A-Fa-f]{6}$' and
    surface_color ~ '^#[0-9A-Fa-f]{6}$' and
    text_primary_color ~ '^#[0-9A-Fa-f]{6}$' and
    text_secondary_color ~ '^#[0-9A-Fa-f]{6}$' and
    border_color ~ '^#[0-9A-Fa-f]{6}$'
  )
);

alter table public.brand_configs enable row level security;

drop policy if exists "Anyone can view brand configs" on public.brand_configs;
drop policy if exists "Developers can manage brand configs" on public.brand_configs;

create policy "Anyone can view brand configs"
on public.brand_configs for select using (true);

create policy "Developers can manage brand configs"
on public.brand_configs for all
using (public.is_developer())
with check (public.is_developer());

create or replace function public.set_brand_configs_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

revoke all on function public.set_brand_configs_updated_at() from public;
grant execute on function public.set_brand_configs_updated_at() to authenticated;

drop trigger if exists set_brand_configs_updated_at on public.brand_configs;
create trigger set_brand_configs_updated_at
before update on public.brand_configs
for each row execute function public.set_brand_configs_updated_at();

insert into public.brand_configs (brand_key, app_name)
values ('halalfood', 'HALAL Food')
on conflict (brand_key) do nothing;

grant select on public.brand_configs to anon, authenticated;
grant insert, update, delete on public.brand_configs to authenticated;
