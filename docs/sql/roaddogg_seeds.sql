-- roaddogg_seeds.sql (optional)
-- Replace org UUIDs as needed

INSERT INTO st_zones(org_id, code, name) VALUES
  ('00000000-0000-0000-0000-0000000000a1','ATL_HUB','Atlanta Hub'),
  ('00000000-0000-0000-0000-0000000000a1','DAL_HUB','Dallas Hub')
ON CONFLICT DO NOTHING;

INSERT INTO st_edges(org_id, from_zone, to_zone, distance_km, typical_duration_min)
SELECT z1.org_id, z1.id, z2.id, 1200, 780
FROM st_zones z1 JOIN st_zones z2 ON z1.code='ATL_HUB' AND z2.code='DAL_HUB'
ON CONFLICT DO NOTHING;

INSERT INTO ml_datasets(org_id, name, description)
VALUES ('00000000-0000-0000-0000-0000000000a1','capacity_ds_v1','historical supply/demand + features')
ON CONFLICT DO NOTHING;
