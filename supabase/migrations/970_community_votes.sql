create table if not exists public.community_votes (
  id bigserial primary key,
  post_id uuid not null references public.community_posts(id) on delete cascade,
  voter uuid not null references public.profiles(user_id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(post_id, voter)
);

alter table public.community_votes enable row level security;
create policy if not exists "votes_read" on public.community_votes for select using ( true );
create policy if not exists "votes_ins_self" on public.community_votes for insert with check ( voter = auth.uid() );

create or replace view public.community_posts_ranked as
select p.*, coalesce(v.cnt,0) as votes
from public.community_posts p
left join (
  select post_id, count(*) as cnt
  from public.community_votes
  group by 1
) v on v.post_id = p.id;
