// apps/web/src/pages/api/status/incidents.ts
import type { NextApiRequest, NextApiResponse } from 'next'
import { createClient } from '@supabase/supabase-js'

export default async function handler(_req: NextApiRequest, res: NextApiResponse) {
  const url = process.env.SUPABASE_URL!
  const anon = process.env.SUPABASE_ANON_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  const db = createClient(url, anon)
  const { data, error } = await db
    .from('status_incidents')
    .select('id,title,status,impact,started_at,resolved_at,updates')
    .order('started_at', { ascending: false })
    .limit(20)
  if (error) return res.status(500).json({ error: error.message })
  res.status(200).json({ incidents: data ?? [] })
}
