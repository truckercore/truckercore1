-- docs/sql/announcements_delivery.sql
create table if not exists public.announcement_receipts(
  announcement_id uuid not null,
  user_id uuid not null,
  delivered_at timestamptz,
  failed_at timestamptz,
  attempts int default 0,
  primary key (announcement_id, user_id)
);

create table if not exists public.announcement_retry_queue(
  id bigserial primary key,
  announcement_id uuid not null,
  user_id uuid not null,
  not_before timestamptz not null default now(),
  attempts int default 0
);
