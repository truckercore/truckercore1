begin;

create table if not exists public.driver_forums (
  id uuid primary key default gen_random_uuid(),
  topic text not null,
  created_by uuid not null,
  created_at timestamptz not null default now()
);

create table if not exists public.forum_posts (
  id uuid primary key default gen_random_uuid(),
  forum_id uuid not null references public.driver_forums(id) on delete cascade,
  author_id uuid not null,
  body text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.driver_referrals (
  id uuid primary key default gen_random_uuid(),
  referrer_id uuid not null,
  referee_email text not null,
  reward_points int default 100,
  created_at timestamptz not null default now()
);

commit;