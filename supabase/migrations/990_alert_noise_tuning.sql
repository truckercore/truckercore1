-- 990_alert_noise_tuning.sql
-- Tune alert rule thresholds to reduce Slack noise during pilots
update public.alert_rules
set threshold = 3, window_minutes = 30
where key = 'fn_failures_gt_N';
