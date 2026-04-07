import { describe, it, expect } from 'vitest'
import { severityBucket } from '../SafetyLite'

describe('severityBucket', () => {
  it('maps to correct buckets', () => {
    expect(severityBucket(undefined)).toBe('none')
    expect(severityBucket(0 as any)).toBe('none')
    expect(severityBucket(1)).toBe('low')
    expect(severityBucket(2)).toBe('low')
    expect(severityBucket(3)).toBe('medium')
    expect(severityBucket(4)).toBe('high')
    expect(severityBucket(5)).toBe('high')
  })
})
