create extension if not exists pgcrypto;

create table if not exists public.app_config (
  id text primary key default 'singleton',
  company_name text not null default '',
  admin_name text not null default '',
  admin_email text not null default '',
  admin_password text not null default '',
  phone text not null default '',
  welcome_message text not null default 'No content has been assigned yet.',
  logo_url text not null default '',
  accent_color_hex text not null default '#0F766E',
  apk_base_url text not null default '',
  local_project_path text not null default '',
  screen_player_orientation text not null default 'landscape'
);

create table if not exists public.clients (
  id text primary key default gen_random_uuid()::text,
  name text not null default '',
  contact_name text not null default '',
  contact_email text not null default '',
  phone text not null default '',
  notes text not null default '',
  created_at text not null default now()::text
);

create table if not exists public.screens (
  id uuid primary key default gen_random_uuid(),
  name text not null default '',
  login_code text not null unique,
  password text not null default '',
  location text not null default '',
  screen_player_orientation text not null default 'landscape',
  assigned_media_ids text[] not null default '{}',
  last_seen_at text,
  play_count integer not null default 0,
  last_playback_at text
);

create table if not exists public.media_items (
  id uuid primary key default gen_random_uuid(),
  client_id text references public.clients(id) on delete cascade,
  title text not null default '',
  url text not null default '',
  kind text not null default 'video',
  description text not null default '',
  duration_seconds integer not null default 15,
  created_at text not null default now()::text,
  storage_path text
);

create table if not exists public.media_playback (
  id text primary key default gen_random_uuid()::text,
  media_id text not null,
  screen_id text not null,
  play_count integer not null default 0,
  last_played_at text,
  play_date text not null default '',
  constraint media_playback_media_screen_date_unique unique (media_id, screen_id, play_date)
);

alter table if exists public.app_config
add column if not exists apk_base_url text not null default '';

alter table if exists public.app_config
add column if not exists local_project_path text not null default '';

alter table if exists public.app_config
add column if not exists screen_player_orientation text not null default 'landscape';

alter table if exists public.screens
add column if not exists play_count integer not null default 0;

alter table if exists public.screens
add column if not exists screen_player_orientation text not null default 'landscape';

alter table if exists public.screens
add column if not exists last_playback_at text;

alter table if exists public.media_items
add column if not exists client_id text;

do $$
declare
  fallback_client_id text := 'default-client';
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'media_items'
      and column_name = 'client_id'
  ) then
    if exists (
      select 1
      from public.media_items
      where client_id is null or client_id = ''
    ) then
      insert into public.clients (
        id,
        name,
        contact_name,
        contact_email,
        phone,
        notes,
        created_at
      )
      values (
        fallback_client_id,
        'Default Client',
        'Imported Records',
        '',
        '',
        'Created automatically for existing media items.',
        now()::text
      )
      on conflict (id) do nothing;

      update public.media_items
      set client_id = fallback_client_id
      where client_id is null or client_id = '';
    end if;
  end if;
end $$;

insert into public.app_config (
  id,
  company_name,
  admin_name,
  admin_email,
  admin_password
)
values (
  'singleton',
  'Brand Slots',
  'Admin',
  'admin@brandslots.com',
  'admin123'
)
on conflict (id) do update
set
  company_name = case
    when public.app_config.company_name = '' then excluded.company_name
    else public.app_config.company_name
  end,
  admin_name = case
    when public.app_config.admin_name = '' then excluded.admin_name
    else public.app_config.admin_name
  end,
  admin_email = case
    when public.app_config.admin_email = '' then excluded.admin_email
    else public.app_config.admin_email
  end,
  admin_password = case
    when public.app_config.admin_password = '' then excluded.admin_password
    else public.app_config.admin_password
  end,
  screen_player_orientation = case
    when public.app_config.screen_player_orientation = '' then excluded.screen_player_orientation
    else public.app_config.screen_player_orientation
  end;

alter table public.app_config replica identity full;
alter table public.clients replica identity full;
alter table public.screens replica identity full;
alter table public.media_items replica identity full;
alter table public.media_playback replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.app_config;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.clients;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.screens;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.media_items;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.media_playback;
exception
  when duplicate_object then null;
end $$;

alter table public.app_config disable row level security;
alter table public.clients disable row level security;
alter table public.screens disable row level security;
alter table public.media_items disable row level security;
alter table public.media_playback disable row level security;

insert into storage.buckets (id, name, public)
values ('media', 'media', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists "Public media objects are viewable" on storage.objects;
create policy "Public media objects are viewable"
on storage.objects
for select
to public
using (bucket_id = 'media');

drop policy if exists "Public media objects can be uploaded" on storage.objects;
create policy "Public media objects can be uploaded"
on storage.objects
for insert
to public
with check (bucket_id = 'media');

drop policy if exists "Public media objects can be updated" on storage.objects;
create policy "Public media objects can be updated"
on storage.objects
for update
to public
using (bucket_id = 'media')
with check (bucket_id = 'media');

drop policy if exists "Public media objects can be deleted" on storage.objects;
create policy "Public media objects can be deleted"
on storage.objects
for delete
to public
using (bucket_id = 'media');

-- Migration: add play_date column and fix unique constraint to be per-day
alter table if exists public.media_playback
add column if not exists play_date text not null default '';

do $$
begin
  -- Drop the old (media_id, screen_id) unique constraint if it exists
  if exists (
    select 1 from information_schema.table_constraints
    where table_schema = 'public'
      and table_name = 'media_playback'
      and constraint_name = 'media_playback_media_screen_unique'
  ) then
    alter table public.media_playback
      drop constraint media_playback_media_screen_unique;
  end if;

  -- Add the new (media_id, screen_id, play_date) unique constraint if missing
  if not exists (
    select 1 from information_schema.table_constraints
    where table_schema = 'public'
      and table_name = 'media_playback'
      and constraint_name = 'media_playback_media_screen_date_unique'
  ) then
    alter table public.media_playback
      add constraint media_playback_media_screen_date_unique
      unique (media_id, screen_id, play_date);
  end if;
end $$;

-- RPC: increment screen play count
create or replace function increment_screen_play_count(
  p_screen_id text,
  p_count integer,
  p_last_playback_at text
) returns void language plpgsql as $$
begin
  update public.screens
  set
    play_count = play_count + p_count,
    last_playback_at = p_last_playback_at
  where id::text = p_screen_id;
end;
$$;

-- RPC: upsert per-day play count for a media+screen
create or replace function increment_media_play_count(
  p_media_id text,
  p_screen_id text,
  p_play_date text,
  p_count integer,
  p_last_played_at text
) returns void language plpgsql as $$
begin
  insert into public.media_playback (id, media_id, screen_id, play_count, last_played_at, play_date)
  values (gen_random_uuid()::text, p_media_id, p_screen_id, p_count, p_last_played_at, p_play_date)
  on conflict (media_id, screen_id, play_date)
  do update set
    play_count = public.media_playback.play_count + excluded.play_count,
    last_played_at = excluded.last_played_at;
end;
$$;

-- Round tracking: rounds are stored in media_playback with media_id = '__round__'
-- play_count in those rows = round count for that screen on that date.
-- No schema change needed; the existing increment_media_play_count RPC handles it.
-- To query rounds per screen per day:
--   SELECT screen_id, play_date, play_count AS round_count
--   FROM media_playback WHERE media_id = '__round__'
--   ORDER BY screen_id, play_date;
