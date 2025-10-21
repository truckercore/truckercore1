create table if not exists feature_registry (
  key text, env text,
  description text, owner text, runbook_url text,
  enabled boolean not null default false,
  updated_at timestamptz default now(),
  primary key (key, env)
);

create or replace view v_features_live as
select key, env, enabled, owner, runbook_url, updated_at
from feature_registry
where enabled = true
order by key, env;
