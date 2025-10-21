// api/lib/blocklist.ts
// Helper functions to register violations with exponential backoff and check block status.
import type { createClient } from '@supabase/supabase-js'

type DB = ReturnType<typeof createClient>

export async function registerViolation(db: any, ip: string, baseMinutes = 10) {
  try {
    const { data } = await db.from('ip_blocklist').select('hits').eq('ip', ip).maybeSingle()
    const hits = ((data?.hits as number | undefined) ?? 0) + 1
    const mins = baseMinutes * Math.pow(2, Math.min(hits - 1, 6)) // cap growth
    const until = new Date(Date.now() + mins * 60000).toISOString()
    await db.from('ip_blocklist')
      .upsert({ ip, reason: 'repeat-abuse', hits, blocked_until: until, last_seen: new Date().toISOString() }, { onConflict: 'ip' })
  } catch (_) { /* ignore */ }
}

export async function isBlocked(db: any, ip: string) {
  try {
    const { data } = await db.from('v_ip_blocked_now').select('ip').eq('ip', ip)
    return Array.isArray(data) && data.length > 0
  } catch {
    return false
  }
}
