# Model Card: ETA (Estimated Time of Arrival)

- Intended use: Provide near-term ETA estimates for trips given coarse features (distance_km, avg_speed_hist, hour_of_day, day_of_week). Not for legal/compliance decisions.
- Users: Internal dispatch, operator dashboards, pilot orgs with entitlement.
- Data sources: Feature vectors logged from Edge Function requests (PII minimized). Ground truth from feedback events (ai_feedback_events).
- Training: Incremental/periodic retraining from joined inference+feedback (see trainer/eta_online.py). Versioned in ai_model_versions; rollouts managed via ai_rollouts.
- Metrics: MAE (min), RMSE (min) aggregated in ai_accuracy_rollups. SLO: p95 latency ≤ 1200 ms.
- Limitations: Sensitivity to traffic/weather not modeled fully; sparse data in some cohorts (night/long-haul). Predictions degrade under drift; monitored via PSI.
- Safety & Ethics: Decision audits recorded in ai_decision_audit; XAI endpoint exposes features/prediction. No PII stored in features; IDs hashed/bucketed upstream. Retention: raw events ≤90d, aggregates retained.
- Rollout policy: Canary 10%→50%→100% with health/accuracy monitors; rollback to last active if regressions detected.
