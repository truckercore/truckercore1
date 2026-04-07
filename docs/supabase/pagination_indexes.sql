-- Index suggestions to back keyset pagination RPCs and common sort keys
-- Apply only if the underlying views/tables expose these columns.

-- Lane ROI view/table sorted by profit_usd desc, id desc
-- (If v_lane_roi_and_detention is a view, ensure underlying tables have suitable indexes.)
-- Example underlying table index:
-- create index if not exists idx_loads_profit_id on public.loads (profit_usd desc, id desc);

-- Detention by facility sorted by avg_minutes desc, id desc
-- Example underlying table index:
-- create index if not exists idx_detention_avg_id on public.facilities_detention (avg_minutes desc, id desc);

-- General guidance
-- - Prefer keyset pagination (WHERE (metric < cursor_metric) OR (metric = cursor_metric AND id < cursor_id))
-- - Cap limits (<= 200) and set statement timeouts on server-side endpoints/RPCs
-- - Avoid OFFSET for deep pagination on large datasets
