-- Developer branding configuration.
-- Production-safe: no secrets are stored here.

create table if not exists public.app_branding (
  id boolean primary key default true check (id = true),
  app_name text not null default 'HALAL Food',
  logo_url text,
  primary_color text not null default '#0B6B3A',
  secondary_color text not null default '#064B2A',
  accent_color text not null default '#D4A72C',
  updated_at timestamptz not null default now()
);

insert into public.app_branding (id)
values (true)
on conflict (id) do nothing;

alter table public.app_branding enable row level security;

drop policy if exists "Developer can manage app branding" on public.app_branding;
create policy "Developer can manage app branding"
on public.app_branding
for all
to authenticated
using (public.is_developer())
with check (public.is_developer());

drop trigger if exists set_app_branding_updated_at on public.app_branding;
create trigger set_app_branding_updated_at
before update on public.app_branding
for each row execute function public.update_updated_at();
