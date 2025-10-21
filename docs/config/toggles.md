# Config Toggles (Edge Functions)

These environment variables control behavior of the POI fusion, speed tiles, and forecasting jobs. All are optional; sane defaults are used if missing.

Fusion (cron.aggregate_poi_states)
- DECAY_HALFLIFE_MIN (alias: DECAY_HALF_LIFE_MIN)
  - Meaning: Exponential half-life for time decay applied to reports (minutes).
  - Default: 30
  - Range: 1–1440
- FUSION_WINDOW_MIN
  - Meaning: Lookback window for considering recent reports (minutes).
  - Default: 120
  - Range: 5–720
- OPERATOR_WEIGHT
  - Meaning: Weight mass applied to operator-sourced reports (payload.source == 'operator').
  - Default: 1.0
  - Range: 0.1–10
- CROWD_MIN_TRUST
  - Meaning: Minimum trust floor for crowd reports; actual trust is max(trust_snapshot, CROWD_MIN_TRUST).
  - Default: 0.2
  - Range: 0.0–1.0

Speed tiles (cron.speed_tiles_v1)
- SPEED_WINDOW_MIN
  - Meaning: Lookback window in minutes for GPS sample aggregation.
  - Default: 15
  - Range: 5–120
- SPEED_TILE_ZOOM
  - Meaning: WebMercator zoom level for tiles (integer).
  - Default: 12
  - Range: 8–16

Forecasting
- FORECAST_LOOKBACK_DAYS (cron.parking_forecast_rollup)
  - Meaning: Days to look back when computing rolling averages.
  - Default: 28
  - Range: 7–90

How to set
- Supabase Dashboard → Edge Functions → Settings → Environment Variables → Add/Update.
- Changes take effect on next deploy or cold start of the function.

Notes
- cron.aggregate_poi_states also reads app_settings.decay_half_life_min (DB) if present, taking precedence over env for decay.
- All functions emit structured JSON logs with `event` fields you can scrape into dashboards.
