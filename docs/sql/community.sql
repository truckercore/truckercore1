create table if not exists public.forum_topics (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  created_by uuid not null,
  created_at timestamptz default now()
);

create table if not exists public.forum_posts (
  id uuid primary key default gen_random_uuid(),
  topic_id uuid not null references public.forum_topics(id) on delete cascade,
  author_id uuid not null,
  body text not null,
  language text default 'en',
  created_at timestamptz default now()
);

alter table public.forum_topics enable row level security;
alter table public.forum_posts enable row level security;

create policy forum_read on public.forum_topics for select using (true);
create policy forum_write on public.forum_topics for insert with check (auth.uid() = created_by);
create policy posts_read on public.forum_posts for select using (true);
create policy posts_write on public.forum_posts for insert with check (auth.uid() = author_id);
