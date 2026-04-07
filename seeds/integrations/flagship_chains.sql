-- seeds/integrations/flagship_chains.sql
begin;
insert into partner_chains (chain_id, display_name) values
  ('flyingj','Flying J'),
  ('loves','Love''s')
on conflict (chain_id) do nothing;

-- Example store mappings (org_id references tenant table)
insert into partner_stores (chain_id, store_id, org_id) values
  ('flyingj','123','00000000-0000-0000-0000-000000000001'),
  ('loves','567','00000000-0000-0000-0000-000000000002')
on conflict (chain_id, store_id) do nothing;

-- Example devices (use throwaway secrets in non-prod)
insert into devices (chain_id, store_id, device_type, external_id, hmac_secret, enabled) values
  ('flyingj','123','pos','kiosk-1','testsecret-pos-123',true),
  ('flyingj','123','sensor','lot-sensor-7','testsecret-sensor-7',true),
  ('loves','567','pos','kiosk-9','testsecret-pos-567',true)
on conflict (chain_id, store_id, external_id) do nothing;
commit;


-- Additional flagship seed entries (idempotent)
insert into partner_chains(chain_id, display_name)
values ('flyingj','Pilot / Flying J')
on conflict (chain_id) do nothing;

insert into partner_stores(chain_id, store_id, org_id)
values ('flyingj','123','00000000-0000-0000-0000-000000000123'::uuid)
on conflict do nothing;

insert into devices(chain_id, store_id, device_type, external_id, hmac_secret)
values ('flyingj','123','pos','kiosk-1','testsecret')
on conflict do nothing;
