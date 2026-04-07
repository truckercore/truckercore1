import { useEffect, useRef } from 'react'
import { createClient } from '@supabase/supabase-js'

const sb = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
)

export function useHazardSuite(currentRoute?: number[][]) {
  const timer = useRef<NodeJS.Timeout | null>(null)

  useEffect(() => {
    const ch = sb
      .channel('safety_alerts')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'safety_alerts' }, (p) => {
        const msg = (p as any).new?.message || 'Safety alert.'
        try {
          new Audio('/sounds/warn.mp3').play()
        } catch {}
        if (typeof window !== 'undefined' && 'speechSynthesis' in window) {
          try {
            speechSynthesis.speak(new SpeechSynthesisUtterance(msg))
          } catch {}
        }
        // TODO: surface in a toast/banner system
      })
      .subscribe()

    timer.current = setInterval(() => {
      if (typeof navigator === 'undefined' || !('geolocation' in navigator)) return
      navigator.geolocation.getCurrentPosition(async (pos) => {
        const speedKph = Math.max(0, (pos.coords.speed ?? 0) * 3.6)
        const session = await sb.auth.getSession()
        try {
          await fetch(`${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/detect-hazards`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              Authorization: `Bearer ${session.data.session?.access_token}`,
            },
            body: JSON.stringify({
              lat: pos.coords.latitude,
              lng: pos.coords.longitude,
              speedKph,
              route: currentRoute || [],
            }),
          })
        } catch {
          // ignore errors
        }
      })
    }, 12000)

    return () => {
      try { ch.unsubscribe() } catch {}
      if (timer.current) clearInterval(timer.current)
    }
  }, [currentRoute])
}
