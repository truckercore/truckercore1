// TypeScript
import { describe, it, expect } from "vitest";
import { inBBox, haversineDistanceMeters, clusterByProximity } from "./geo";

describe("geo utils", () => {
  it("inBBox works", () => {
    const bbox: [number, number, number, number] = [-123, 37, -121, 38];
    expect(inBBox(37.5, -122.2, bbox)).toBe(true);
    expect(inBBox(36.9, -122.2, bbox)).toBe(false);
  });

  it("haversineDistanceMeters roughly computes SF blocks", () => {
    const d = haversineDistanceMeters([37.7749, -122.4194],[37.7755,-122.4180]);
    expect(d).toBeGreaterThan(100);
    expect(d).toBeLessThan(200);
  });

  it("clusters by proximity", () => {
    const hazards = [
      { id:"1", type:"collision", severity:"high", status:"active", lat:0, lng:0, detected_at:"", updated_at:"" },
      { id:"2", type:"collision", severity:"high", status:"active", lat:0, lng:0.001, detected_at:"", updated_at:"" },
      { id:"3", type:"roadwork", severity:"low", status:"active", lat:1, lng:1, detected_at:"", updated_at:"" },
    ] as any;
    const clusters = clusterByProximity(hazards, 200);
    expect(clusters.length).toBe(2);
  });
});
