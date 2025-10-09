import { useEffect, useRef, useState } from 'react'
import maplibregl, { Map as MapLibreMap } from 'maplibre-gl'
import 'maplibre-gl/dist/maplibre-gl.css'
import { createClient } from '@supabase/supabase-js'

type Alert = {
  id: string
  alert_type: 'SLOWDOWN'|'WORKZONE'|'WEATHER'|'SPEED'|'OFFROUTE'|'WEIGH'|'FATIGUE'
  lat: number
  lng: number
  fired_at: string
  severity: number
  road_name?: string | null
  message: string
}

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
)

const TYPE_COLOR: Record<Alert['alert_type'], string> = {
  SLOWDOWN: '#ef4444', // red
  WORKZONE: '#f59e0b', // amber
  WEATHER: '#3b82f6', // blue
  SPEED: '#dc2626', // red-700
  OFFROUTE: '#dc2626', // red-700
  WEIGH: '#22c55e', // green
  FATIGUE: '#a855f7', // purple
}

function toGeoJSON(alerts: Alert[]): GeoJSON.FeatureCollection<GeoJSON.Point, any> {
  return {
    type: 'FeatureCollection',
    features: alerts.map((a) => ({
      type: 'Feature',
      geometry: { type: 'Point', coordinates: [a.lng, a.lat] },
      properties: {
        id: a.id,
        type: a.alert_type,
        color: TYPE_COLOR[a.alert_type],
        message: a.message,
        fired_at: a.fired_at,
        road: a.road_name || 'Road',
        severity: a.severity,
      },
    })),
  }
}

export default function FleetHazardMap() {
  const mapRef = useRef<MapLibreMap | null>(null)
  const containerRef = useRef<HTMLDivElement | null>(null)
  const [alerts, setAlerts] = useState<Alert[]>([])

  useEffect(() => {
    let cancelled = false
    const load = async () => {
      const since = new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString()
      const { data } = await supabase
        .from('safety_alerts')
        .select('id, alert_type, lat, lng, fired_at, severity, road_name, message')
        .gte('fired_at', since)
        .in('alert_type', ['SLOWDOWN','WORKZONE','WEATHER','SPEED','OFFROUTE','WEIGH','FATIGUE'])
        .order('fired_at', { ascending: false })
        .limit(1000)
      if (!cancelled) setAlerts((data as any) || [])
    }
    load()

    const ch = supabase
      .channel('safety_alerts_map')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'safety_alerts' }, (p: any) => {
        const row = p.new as Alert
        setAlerts(prev => [row, ...prev].slice(0, 1000))
      })
      .subscribe()

    return () => {
      cancelled = true
      supabase.removeChannel(ch)
    }
  }, [])

  useEffect(() => {
    if (mapRef.current || !containerRef.current) return
    const map = new maplibregl.Map({
      container: containerRef.current,
      style: 'https://demotiles.maplibre.org/style.json',
      center: [-98.5795, 39.8283],
      zoom: 3.2,
    })
    mapRef.current = map

    map.on('load', () => {
      map.addSource('hazards', {
        type: 'geojson',
        data: toGeoJSON([]) as any,
        cluster: true,
        clusterMaxZoom: 11,
        clusterRadius: 50,
      } as any)

      map.addLayer({
        id: 'clusters',
        type: 'circle',
        source: 'hazards',
        filter: ['has', 'point_count'],
        paint: {
          'circle-color': '#64748b',
          'circle-radius': [
            'step',
            ['get', 'point_count'],
            16, 25,
            20, 50,
            26
          ],
          'circle-stroke-width': 1,
          'circle-stroke-color': '#0f172a'
        }
      })

      map.addLayer({
        id: 'cluster-count',
        type: 'symbol',
        source: 'hazards',
        filter: ['has', 'point_count'],
        layout: {
          'text-field': ['get', 'point_count_abbreviated'],
          'text-font': ['Open Sans Regular'],
          'text-size': 12
        },
        paint: { 'text-color': '#e2e8f0' }
      })

      map.addLayer({
        id: 'hazard-points',
        type: 'circle',
        source: 'hazards',
        filter: ['!', ['has', 'point_count']],
        paint: {
          'circle-color': ['get', 'color'],
          'circle-radius': [
            'interpolate',
            ['linear'],
            ['number', ['get', 'severity'], 1],
            1, 5,
            5, 10
          ],
          'circle-stroke-color': '#0b1220',
          'circle-stroke-width': 1
        }
      })

      map.on('click', 'hazard-points', (e) => {
        const f = e.features?.[0]
        if (!f) return
        const coords = (f.geometry as any).coordinates.slice()
        const props = f.properties as any
        new maplibregl.Popup({ closeButton: false })
          .setLngLat(coords)
          .setHTML(`
            <div style="font: 12px/1.3 system-ui, -apple-system, Segoe UI, Roboto;">
              <div><strong>${props.type}</strong></div>
              <div>${props.road}</div>
              <div>${new Date(props.fired_at).toLocaleString()}</div>
              <div>${props.message ?? ''}</div>
            </div>
          `)
          .addTo(map)
      })

      map.on('mouseenter', 'hazard-points', () => { if (map.getCanvas()) map.getCanvas().style.cursor = 'pointer' })
      map.on('mouseleave', 'hazard-points', () => { if (map.getCanvas()) map.getCanvas().style.cursor = '' })
    })

    return () => {
      map.remove()
      mapRef.current = null
    }
  }, [])

  useEffect(() => {
    const map = mapRef.current
    if (!map) return
    const src = map.getSource('hazards') as any
    if (src) src.setData(toGeoJSON(alerts) as any)
  }, [alerts])

  return <div ref={containerRef} style={{ width: '100%', height: '420px', borderRadius: 8, overflow: 'hidden' }} />
}
