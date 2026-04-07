# Events & POI Reporting API (Edge Functions)

Endpoints
- POST /functions/v1/events.gps.ingest
  Body: { org_id?: string, coarse?: boolean, samples: [{ lat, lng, speed_kph?, heading_deg?, accuracy_m?, source?: 'mobile'|'sdk', ts?: ISO }...] }
  Returns: { ok: true, accepted: number, skipped: number }

- POST /functions/v1/events.poi.report
  Body: { poi_id: uuid, kind: 'parking'|'weigh'|'incident'|'fuel', status?: string, payload?: object, photo_url?: string, lat?: number, lng?: number }
  Returns: { id, trust_snapshot, ts }

- POST /functions/v1/events.vote
  Body: { report_id: uuid, vote: -1|1 }
  Returns: { ok: true, up: number, down: number }

Scheduled jobs
- cron.aggregate_poi_states: aggregates last ~60 minutes of reports into parking_state and weigh_station_state with confidence and source_mix
- cron.trust_recalc: nightly trust recalculation using agreement with latest posterior

Notes
- Privacy: clients can set `coarse=true` to round coordinates (~75m). Server may enforce further throttling when stationary.
- Rate limits: basic server-side guards added (GPS: 200/5min per user; POI reports: 1 per 10min per user+poi+kind; duplicate suppression 5min).
- Trust: initial heuristic uses account age, email verification, fleet membership; refined nightly via agreement.
- RLS: gps_samples insert-only; poi_reports insert + read; votes insert + read; states read-only.

Curl examples
```
# GPS ingest (batched)
curl -X POST "$SUPABASE_URL/functions/v1/events.gps.ingest" \
  -H "Authorization: Bearer $USER_JWT" \
  -H 'content-type: application/json' \
  -d '{
    "coarse": true,
    "samples": [
      {"lat": 35.12, "lng": -97.51, "speed_kph": 96.4, "heading_deg": 180, "accuracy_m": 8},
      {"lat": 35.13, "lng": -97.52, "speed_kph": 100.1}
    ]
  }'

# Report parking status
curl -X POST "$SUPABASE_URL/functions/v1/events.poi.report" \
  -H "Authorization: Bearer $USER_JWT" \
  -H 'content-type: application/json' \
  -d '{"poi_id":"UUID","kind":"parking","status":"open"}'

# Vote on a report
curl -X POST "$SUPABASE_URL/functions/v1/events.vote" \
  -H "Authorization: Bearer $USER_JWT" \
  -H 'content-type: application/json' \
  -d '{"report_id":"UUID","vote":1}'
```