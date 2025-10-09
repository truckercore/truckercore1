begin;

create table if not exists org_alert_thresholds (
  org_id uuid primary key,
  roi_spike_multiple numeric not null default 3.0,
  roi_rollup_stale_hours int not null default 24
);

create table if not exists alert_escalations (
  id bigserial primary key,
  path text not null,
  active boolean not null default true,
  note text
);

commit;
