-- Screen media assignment tracking
create table if not exists public.screen_media_assignments (
  id text primary key default gen_random_uuid()::text,
  screen_id text not null,
  media_id text not null,
  assigned_at_round integer not null default 0,
  removed_at_round integer
);

alter table public.screen_media_assignments replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.screen_media_assignments;
exception
  when duplicate_object then null;
end $$;

alter table public.screen_media_assignments disable row level security;

-- Backfill existing assignments from screens table
insert into public.screen_media_assignments (screen_id, media_id, assigned_at_round)
select
  s.id::text as screen_id,
  unnest(s.assigned_media_ids) as media_id,
  0 as assigned_at_round
from public.screens s
where array_length(s.assigned_media_ids, 1) > 0
on conflict do nothing;
