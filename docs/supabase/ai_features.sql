-- docs/supabase/ai_features.sql
-- Seed experimental AI feature keys into public.features. Idempotent.

insert into public.features(key, description) values
('ai_profit_coach','AI margin tips and profitability coaching'),
('ai_load_suggestions','Ranked load suggestions using AI signals')
on conflict (key) do update set description = excluded.description;
