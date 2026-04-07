begin;

create table if not exists region_policies (
  region_code text primary key,
  residency text not null check (residency in ('in-region-only','global')),
  api_quota_month int default 100000
);

create or replace view v_org_region as
select o.id as org_id, coalesce(o.region_code,'US') as region_code
from orgs o;

commit;
