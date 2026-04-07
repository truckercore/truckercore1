// apps/web/src/pages/api/feature_catalog.ts
import type { NextApiRequest, NextApiResponse } from 'next'
import { createClient } from '@supabase/supabase-js'

// Server-side Supabase client using service role if available, otherwise anon (read-only)
const SUPABASE_URL = process.env.SUPABASE_URL as string
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY as string | undefined
const ANON_KEY = process.env.SUPABASE_ANON_KEY as string | undefined

const admin = createClient(
  SUPABASE_URL,
  (SERVICE_KEY || ANON_KEY) as string,
  { auth: { persistSession: false } }
)

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  try {
    if (req.method !== 'GET') {
      res.status(405).json({ status: 'error', code: 'bad_request', message: 'Use GET' })
      return
    }
    const locale = (req.query.locale as string | undefined) || undefined
    let q = admin.from('feature_catalog').select('*')
    if (locale) q = q.eq('locale', locale)
    const { data, error } = await q
    if (error) {
      res.status(500).json({ status: 'error', code: 'internal_error', message: error.message })
      return
    }
    res.status(200).json({ status: 'ok', items: data ?? [] })
  } catch (e: any) {
    res.status(500).json({ status: 'error', code: 'internal_error', message: String(e?.message ?? e) })
  }
}
