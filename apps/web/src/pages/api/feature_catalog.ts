// apps/web/src/pages/api/feature_catalog.ts
import type { NextApiRequest, NextApiResponse } from 'next'
import { createAdminClient } from '@/lib/supabase/admin'

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  const admin = createAdminClient();
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
