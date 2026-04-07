begin;

-- Ensure snapshot_id/comment columns exist on ai_roi_baselines if created earlier without them
alter table if exists public.ai_roi_baselines
  add column if not exists snapshot_id uuid not null default gen_random_uuid(),
  add column if not exists comment text;

commit;
