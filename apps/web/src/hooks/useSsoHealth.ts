// apps/web/src/hooks/useSsoHealth.ts
import useSWR from 'swr'
import { supabase } from '@/lib/supabaseClient'

export type SsoHealth = {
  org_id: string
  last_success_at: string | null
  last_error_at: string | null
  last_error_code: string | null
  last_self_check_at: string | null
  self_check_ok: boolean | null
  idp: string | null
  attempts_24h: number
  failures_24h: number
  updated_at: string
}

export function useSsoHealth(orgId?: string | null) {
  const swr = useSWR<SsoHealth | null>(orgId ? ['sso_health', orgId] : null, {
    fetcher: async () => {
      const { data, error } = await supabase.from('sso_health').select('*').eq('org_id', orgId).maybeSingle()
      if (error) throw error
      return (data ?? null) as any
    },
    revalidateOnFocus: false,
  })

  return {
    health: swr.data,
    loading: swr.isLoading,
    error: swr.error,
  }
}
