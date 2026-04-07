import { describe, it, expect } from 'vitest'
import { haversineMeters, offRouteDistanceM, isSpeeding } from './utils'

describe('geo utils', () => {
  it('haversineMeters ~0 for identical points', () => {
    expect(haversineMeters([40, -74], [40, -74])).toBeLessThan(0.5)
  })

  it('offRouteDistanceM returns finite for valid route', () => {
    const pos:[number,number]=[40.0,-74.0]
    const route:[number,number][]= [ [40.0005,-74.0005], [40.0010,-74.0010], [40.0020,-74.0020] ]
    const d = offRouteDistanceM(pos, route)
    expect(d).toBeGreaterThan(0)
    expect(Number.isFinite(d)).toBe(true)
  })

  it('isSpeeding respects buffer', () => {
    expect(isSpeeding(75, 70, 5)).toBe(true)
    expect(isSpeeding(72, 70, 5)).toBe(false)
    expect(isSpeeding(0, 0)).toBe(false)
  })
})
