import { Counter, Histogram, Registry, collectDefaultMetrics } from "prom-client";

// Ensure singleton across hot reloads
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const g: any = globalThis as any;

if (!g.__TC_METRICS_REG__) {
  g.__TC_METRICS_REG__ = new Registry();
}
const register: Registry = g.__TC_METRICS_REG__;

// Collect default Node.js metrics with a prefix and using our registry
if (!g.__TC_COLLECTED_DEFAULTS__) {
  collectDefaultMetrics({ prefix: "truckercore_", register });
  g.__TC_COLLECTED_DEFAULTS__ = true;
}

export const exportCounter: Counter<string> = g.__TC_EXPORT_COUNTER__ ||
  new Counter({
    name: "truckercore_exports_total",
    help: "Total CSV/PDF exports",
    labelNames: ["kind", "org_id"],
    registers: [register],
  });
if (!g.__TC_EXPORT_COUNTER__) g.__TC_EXPORT_COUNTER__ = exportCounter;

export const checkoutCounter: Counter<string> = g.__TC_CHECKOUT_COUNTER__ ||
  new Counter({
    name: "truckercore_checkouts_total",
    help: "Total Stripe checkouts initiated",
    labelNames: ["plan"],
    registers: [register],
  });
if (!g.__TC_CHECKOUT_COUNTER__) g.__TC_CHECKOUT_COUNTER__ = checkoutCounter;

export const apiLatency: Histogram<string> = g.__TC_API_LATENCY__ ||
  new Histogram({
    name: "truckercore_api_latency_seconds",
    help: "API endpoint latency",
    labelNames: ["route"],
    buckets: [0.1, 0.5, 1, 2, 5],
    registers: [register],
  });
if (!g.__TC_API_LATENCY__) g.__TC_API_LATENCY__ = apiLatency;

// Extended HTTP metrics
export const httpRequestsTotal: Counter<string> = g.__TC_HTTP_REQ_TOTAL__ ||
  new Counter({
    name: "truckercore_http_requests_total",
    help: "Total HTTP requests",
    labelNames: ["method", "route", "status"],
    registers: [register],
  });
if (!g.__TC_HTTP_REQ_TOTAL__) g.__TC_HTTP_REQ_TOTAL__ = httpRequestsTotal;

export const httpRequestDuration: Histogram<string> = g.__TC_HTTP_REQ_DUR__ ||
  new Histogram({
    name: "truckercore_http_request_duration_seconds",
    help: "HTTP request duration in seconds",
    labelNames: ["method", "route", "status"],
    buckets: [0.01, 0.05, 0.1, 0.5, 1, 2, 5],
    registers: [register],
  });
if (!g.__TC_HTTP_REQ_DUR__) g.__TC_HTTP_REQ_DUR__ = httpRequestDuration;

export const customEventsTotal: Counter<string> = g.__TC_CUSTOM_EVENTS__ ||
  new Counter({
    name: "truckercore_custom_events_total",
    help: "Total custom events logged",
    labelNames: ["kind"],
    registers: [register],
  });
if (!g.__TC_CUSTOM_EVENTS__) g.__TC_CUSTOM_EVENTS__ = customEventsTotal;

export function trackRequest(method: string, route: string, status: number, durationSec: number) {
  httpRequestsTotal.inc({ method, route, status: String(status) });
  httpRequestDuration.observe({ method, route, status: String(status) }, durationSec);
}

export { register };
