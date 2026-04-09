'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import { createClient } from '@/lib/supabase/client';

type GpsPoint = {
  id?: string;
  user_id: string;
  latitude: number;
  longitude: number;
  speed_mph?: number | null;
  accuracy_meters?: number | null;
  recorded_at: string;
};

type TruckSettings = {
  mpg?: number | null;
  default_fuel_price?: number | null;
};

type ActiveTrip = {
  id: string;
  user_id: string;
  start_time: string;
  status: 'active' | 'completed' | 'cancelled';
};

type LiveTripMetrics = {
  miles: number;
  avgSpeed: number;
  fuelGallons: number;
  fuelCost: number;
  durationMinutes: number;
  pointCount: number;
};

function haversineMiles(lat1: number, lng1: number, lat2: number, lng2: number) {
  const R = 3958.8;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function round(value: number, places = 2) {
  const factor = 10 ** places;
  return Math.round(value * factor) / factor;
}

function computeMetrics(points: GpsPoint[], settings?: TruckSettings | null): LiveTripMetrics {
  if (!points.length) {
    return { miles: 0, avgSpeed: 0, fuelGallons: 0, fuelCost: 0, durationMinutes: 0, pointCount: 0 };
  }

  let miles = 0;
  let speedSum = 0;
  let speedCount = 0;

  for (let i = 1; i < points.length; i++) {
    const prev = points[i - 1];
    const curr = points[i];
    if ((curr.accuracy_meters ?? 0) > 100) continue;
    const segment = haversineMiles(prev.latitude, prev.longitude, curr.latitude, curr.longitude);
    if (segment > 5) continue;
    miles += segment;
    if ((curr.speed_mph ?? 0) > 0) {
      speedSum += curr.speed_mph ?? 0;
      speedCount += 1;
    }
  }

  const avgSpeed = speedCount ? speedSum / speedCount : 0;
  const mpg = settings?.mpg ?? 6.5;
  const fuelPrice = settings?.default_fuel_price ?? 4.2;
  const adjustedMpg =
    avgSpeed > 70 ? mpg * 0.85 :
    avgSpeed < 45 && avgSpeed > 0 ? mpg * 0.9 :
    mpg;

  const fuelGallons = miles / Math.max(adjustedMpg, 1);
  const fuelCost = fuelGallons * fuelPrice;
  const start = new Date(points[0].recorded_at).getTime();
  const end = new Date(points[points.length - 1].recorded_at).getTime();
  const durationMinutes = Math.max(0, Math.round((end - start) / 60000));

  return {
    miles: round(miles, 1),
    avgSpeed: round(avgSpeed, 1),
    fuelGallons: round(fuelGallons, 2),
    fuelCost: round(fuelCost, 2),
    durationMinutes,
    pointCount: points.length,
  };
}

export function useLiveTripMetrics(activeTrip?: ActiveTrip | null) {
  const supabase = useMemo(() => createClient(), []);
  const [points, setPoints] = useState<GpsPoint[]>([]);
  const [settings, setSettings] = useState<TruckSettings | null>(null);
  const loadedRef = useRef(false);

  useEffect(() => {
    if (!activeTrip?.user_id || !activeTrip.start_time) {
      setPoints([]);
      loadedRef.current = false;
      return;
    }

    let cancelled = false;

    async function loadInitial() {
      const [{ data: gpsPoints }, { data: truckSettings }] = await Promise.all([
        supabase
          .from('gps_locations')
          .select('id, user_id, latitude, longitude, speed_mph, accuracy_meters, recorded_at')
          .eq('user_id', activeTrip!.user_id)
          .gte('recorded_at', activeTrip!.start_time)
          .order('recorded_at', { ascending: true }),
        supabase
          .from('truck_settings')
          .select('mpg, default_fuel_price')
          .eq('user_id', activeTrip!.user_id)
          .maybeSingle(),
      ]);

      if (cancelled) return;
      setPoints((gpsPoints as GpsPoint[]) ?? []);
      setSettings(truckSettings ?? null);
      loadedRef.current = true;
    }

    loadInitial();
    return () => { cancelled = true; };
  }, [supabase, activeTrip?.user_id, activeTrip?.start_time]);

  useEffect(() => {
    if (!activeTrip?.user_id || !loadedRef.current) return;

    const channel = supabase
      .channel(`live-trip-${activeTrip.user_id}-${activeTrip.id}`)
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'gps_locations',
        filter: `user_id=eq.${activeTrip.user_id}`,
      }, (payload) => {
        const next = payload.new as GpsPoint;
        if (new Date(next.recorded_at).getTime() < new Date(activeTrip.start_time).getTime()) return;
        setPoints((prev) => {
          if (prev.some((p) => p.id && next.id && p.id === next.id)) return prev;
          return [...prev, next].sort(
            (a, b) => new Date(a.recorded_at).getTime() - new Date(b.recorded_at).getTime()
          );
        });
      })
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  }, [supabase, activeTrip?.id, activeTrip?.user_id, activeTrip?.start_time]);

  const metrics = useMemo(() => computeMetrics(points, settings), [points, settings]);
  return { points, metrics, settings };
}