-- roaddogg_read_views.sql

CREATE OR REPLACE VIEW v_capacity_imbalance_current AS
select p.org_id, p.ts_target, p.horizon_minutes, p.details, m.name as model_name, m.version
from st_capacity_imbalance_preds p
join ml_models m on m.id = p.model_id
where rls_same_org(p.org_id);

CREATE OR REPLACE VIEW v_active_capacity_models AS
select id, org_id, name, model_family, version
from ml_models
where is_active and rls_same_org(org_id);
