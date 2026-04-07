// deno test -A _tests
import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
// Import helper from the function module
import { computeIsLateUtc } from "../alerts_rule_engine/index.ts";

Deno.test("computeIsLateUtc handles missing ETA as not late", () => {
  assertEquals(computeIsLateUtc(null as any, "2025-03-10T12:00:00Z", 15), false);
});

Deno.test("computeIsLateUtc respects grace window", () => {
  const appt = "2025-03-10T12:00:00Z";
  const etaOnTime = "2025-03-10T12:14:00Z"; // 14 min late < 15 grace
  const etaLate = "2025-03-10T12:16:00Z"; // 16 min late > 15 grace
  assertEquals(computeIsLateUtc(etaOnTime, appt, 15), false);
  assertEquals(computeIsLateUtc(etaLate, appt, 15), true);
});

Deno.test("computeIsLateUtc: DST fall-back boundary (should be UTC-insensitive)", () => {
  // US DST fall 2025-11-02: local clocks fall back, but UTC is monotonic
  const appt = "2025-11-02T06:30:00Z"; // ~1:30am CDT before fallback
  const eta =  "2025-11-02T06:45:00Z"; // 15 min after in UTC
  // grace 10 min → late; grace 20 min → not late
  assertEquals(computeIsLateUtc(eta, appt, 10), true);
  assertEquals(computeIsLateUtc(eta, appt, 20), false);
});

Deno.test("computeIsLateUtc: timezone mismatch scenarios (inputs already UTC)", () => {
  const appt = "2025-06-01T16:00:00Z"; // 12:00 ET local
  const eta =  "2025-06-01T20:30:00Z"; // 13:30 PT local same day (UTC 20:30)
  // 4.5 hours after appt → always late beyond any small grace
  assert(computeIsLateUtc(eta, appt, 15));
});

Deno.test("computeIsLateUtc: early delivery treated as not late", () => {
  const appt = "2025-03-10T12:00:00Z";
  const etaEarly = "2025-03-10T11:50:00Z";
  assertEquals(computeIsLateUtc(etaEarly, appt, 15), false);
});

Deno.test("computeIsLateUtc: ETA rollback (later estimate becomes earlier)", () => {
  const appt = "2025-03-10T12:00:00Z";
  const etaFirst = "2025-03-10T12:25:00Z"; // would be late with 15
  const etaRollback = "2025-03-10T12:05:00Z"; // now within grace
  assertEquals(computeIsLateUtc(etaFirst, appt, 15), true);
  assertEquals(computeIsLateUtc(etaRollback, appt, 15), false);
});
