-- seeds/iam/tenants.sql
begin;
insert into iam_tenants (org_id, org_name, region_code) values
  ('00000000-0000-0000-0000-000000000001','Pilot Org A','US'),
  ('00000000-0000-0000-0000-000000000002','Pilot Org B','US')
on conflict (org_id) do nothing;
commit;
