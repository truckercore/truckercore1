import { useEffect, useRef, useState } from 'react'
import { createClient } from '@supabase/supabase-js'

export type SlowdownAlert = {
  id: string
  alert_type?: string
  message?: string
  fired_at?: string
  road_name?: string
  eta_delta_sec?: number
  speed_ahead_kph?: number
  ahead_distance_m?: number
}

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
)

export function useSlowdownAlerts() {
  const [latest, setLatest] = useState<SlowdownAlert | null>(null)
  const timer = useRef<NodeJS.Timeout | null>(null)

  useEffect(() => {
    // subscribe to realtime inserts for safety_alerts
    const channel = supabase
      .channel('safety_alerts')
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'safety_alerts' },
        (payload) => {
          const row = payload.new as SlowdownAlert
          setLatest(row)
          const msg = row?.message || 'Traffic slowing ahead.'
          try {
            // best-effort chime
            new Audio('/sounds/warn.mp3').play()
          } catch {}
          // optional TTS
          if (typeof window !== 'undefined' && 'speechSynthesis' in window) {
            try {
              speechSynthesis.speak(new SpeechSynthesisUtterance(msg))
            } catch {}
          }
        }
      )
      .subscribe()

    // start periodic location sampling
    timer.current = setInterval(async () => {
      if (typeof navigator === 'undefined' || !('geolocation' in navigator)) return
      navigator.geolocation.getCurrentPosition(async (pos) => {
        const speedKph = Math.max(0, (pos.coords.speed ?? 0) * 3.6)
        const heading = pos.coords.heading ?? 0
        const body = {
          lat: pos.coords.latitude,
          lng: pos.coords.longitude,
          speedKph,
          heading,
        }
        try {
          const jwt = await getJwt()
          await fetch(
            `${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/detect-slowdown`,
            {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                Authorization: `Bearer ${jwt}`,
              },
              body: JSON.stringify(body),
            }
          )
        } catch {
          // ignore sample failure
        }
      })
    }, 12000) // every 12s

    return () => {
      try {
        channel.unsubscribe()
      } catch {}
      if (timer.current) clearInterval(timer.current)
    }
  }, [])

  return { latest }
}

async function getJwt(): Promise<string> {
  const session = (await supabase.auth.getSession()).data.session
  return session?.access_token || ''
}
