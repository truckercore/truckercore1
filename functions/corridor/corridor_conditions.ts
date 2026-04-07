import { serve } from "std/server";
import { makeRequestId, ok, badRequest, error as errResp } from "../lib/http.ts";
import { metricsPush } from "../lib/metrics.ts";

// Corridor Conditions (incidents + weather ETA delta) stub
// Deploy: supabase functions deploy corridor-conditions --no-verify-jwt
// Invoke: supabase functions invoke corridor-conditions -b '{"origin":{"lat":41.88,"lng":-87.63},"destination":{"lat":34.05,"lng":-118.24}}'

function isLatLng(x: any): x is { lat: number; lng: number } {
  return x && typeof x.lat === 'number' && typeof x.lng === 'number'
    && x.lat >= -90 && x.lat <= 90 && x.lng >= -180 && x.lng <= 180;
}

serve(async (req) => {
  const request_id = makeRequestId(req);
  const started = Date.now();
  try {
    const body = await req.json();
    const origin = body.origin;
    const destination = body.destination;
    const polyline = body.polyline; // optional encoded polyline or list of points

    if (!isLatLng(origin) || !isLatLng(destination)) {
      await metricsPush('corridor-conditions', 'bad_request', { reason: 'invalid_origin_or_destination' }, request_id, 1.0);
      return badRequest('origin and destination required (lat,lng)', request_id);
    }

    // Stubbed incidents & weather ETA delta. Replace with provider(s): 511 feeds, HERE/Google/TomTom, NOAA.
    const incidents = [
      { type: 'accident', severity: 'moderate', near: { lat: origin.lat + 0.2, lng: origin.lng - 0.1 }, miles_ahead: 12 },
      { type: 'closure', severity: 'minor', near: { lat: destination.lat - 0.3, lng: destination.lng + 0.15 }, miles_ahead: 45 },
    ];
    const weather = {
      systems: [ { kind: 'crosswind', mph: 28, miles_span: 80 }, { kind: 'snow', intensity: 'light', miles_span: 30 } ],
      eta_delta_minutes: 24, // mock ETA increase from weather
    };

    const latency_ms = Date.now() - started;
    await metricsPush('corridor-conditions', 'ok', {
      latency_ms,
      has_polyline: Boolean(polyline),
      incidents_count: incidents.length,
    }, request_id, 0.5);

    return ok({ origin, destination, incidents, weather, polyline_provided: Boolean(polyline) }, request_id);
  } catch (err) {
    console.error('corridor-conditions error', request_id, err);
    await metricsPush('corridor-conditions', 'error', { message: String(err) }, request_id, 1.0);
    return errResp(String(err), request_id, 500);
  }
});
