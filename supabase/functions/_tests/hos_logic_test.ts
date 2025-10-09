// deno test -A _tests
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { stitchDrivingMs } from "../alerts_rule_engine/index.ts";

type I = { start: number; end: number };

Deno.test("stitchDrivingMs merges overlaps and snaps small gaps", () => {
  const base = Date.parse("2025-03-01T12:00:00Z");
  const fiveMin = 5 * 60 * 1000;
  const twoMin = 2 * 60 * 1000;
  const intervals: I[] = [
    { start: base, end: base + 30 * 60 * 1000 },                // 30m
    { start: base + 28 * 60 * 1000, end: base + 40 * 60 * 1000 }, // overlaps -> merge
    { start: base + 41 * 60 * 1000, end: base + 50 * 60 * 1000 }, // gap 1m -> snap & merge (default 5)
    { start: base + 60 * 60 * 1000, end: base + 70 * 60 * 1000 }, // separate by 10m -> no merge
  ];
  const totalMs = stitchDrivingMs(intervals, 5, true);
  // First three merge into [base, base+50m]; plus last 10m => 60m total
  assertEquals(Math.round(totalMs / 60000), 60);
});

Deno.test("stitchDrivingMs discards invalid and negative intervals", () => {
  const base = Date.parse("2025-03-01T12:00:00Z");
  const intervals: I[] = [
    { start: base, end: base - 1000 }, // invalid
    { start: base + 1000, end: base + 2000 },
  ];
  const totalMs = stitchDrivingMs(intervals, 5, true);
  assertEquals(Math.round(totalMs / 1000), 1);
});

Deno.test("stitchDrivingMs disallows cross-midnight when flag false", () => {
  const d1 = Date.parse("2025-03-01T23:50:00Z");
  const d2 = Date.parse("2025-03-02T00:10:00Z");
  const totalMs = stitchDrivingMs([
    { start: d1, end: d2 }, // crosses midnight
  ], 5, false);
  // Discarded => 0
  assertEquals(totalMs, 0);
});

Deno.test("stitchDrivingMs allows cross-midnight when flag true", () => {
  const d1 = Date.parse("2025-03-01T23:50:00Z");
  const d2 = Date.parse("2025-03-02T00:10:00Z");
  const totalMs = stitchDrivingMs([
    { start: d1, end: d2 },
  ], 5, true);
  assertEquals(Math.round(totalMs / 60000), 20);
});
