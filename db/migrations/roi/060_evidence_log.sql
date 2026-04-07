begin;

create table if not exists roi_report_evidence (
  id bigserial primary key,
  org_id uuid not null,
  month text not null,
  path text not null,
  sha256 text not null,
  signer text not null,
  baseline_snapshot_ids text[] not null default '{}',
  created_at timestamptz not null default now()
);

commit;
