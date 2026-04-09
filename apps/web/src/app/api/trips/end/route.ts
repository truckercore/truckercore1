import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

// Haversine distance in miles
function haversineMiles(lat1: number, lng1: number, lat2: number, lng2: number) {
  const R = 3958.8;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a = Math.sin(dLat/2)**2 +
    Math.cos(lat1 * Math.PI/180) * Math.cos(lat2 * Math.PI/180) *
    Math.sin(dLng/2)**2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
}

// Rough state detection from coordinates
function detectState(lat: number, lng: number): string {
  if (lat >= 36.9 && lat <= 42.5 && lng >= -91.5 && lng <= -87.0) return 'IL';
  if (lat >= 25.8 && lat <= 36.5 && lng >= -106.6 && lng <= -93.5) return 'TX';
  if (lat >= 29.0 && lat <= 33.0 && lng >= -97.0 && lng <= -93.5) return 'TX';
  if (lat >= 41.0 && lat <= 46.0 && lng >= -92.0 && lng <= -82.0) return 'WI';
  if (lat >= 38.0 && lat <= 42.0 && lng >= -84.8 && lng <= -80.5) return 'OH';
  return 'US';
}

export async function POST(req: Request) {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

    const { tripId, endLat, endLng, endAddress, tollCost } = await req.json();

    // Get trip
    const { data: trip } = await supabase
      .from('trips')
      .select('*')
      .eq('id', tripId)
      .eq('user_id', user.id)
      .single();

    if (!trip) return NextResponse.json({ error: 'Trip not found' }, { status: 404 });

    // Get truck settings
    const { data: settings } = await supabase
      .from('truck_settings')
      .select('*')
      .eq('user_id', user.id)
      .maybeSingle();

    const mpg = settings?.mpg ?? 6.5;
    const fuelPrice = settings?.default_fuel_price ?? 4.20;

    // Calculate miles
    const miles = haversineMiles(
      trip.start_lat, trip.start_lng, endLat, endLng
    );

    const fuelUsed = miles / mpg;
    const fuelCost = fuelUsed * fuelPrice;
    const totalTollCost = tollCost ?? 0;

    // Detect state for IFTA
    const state = detectState(endLat, endLng);
    const now = new Date();
    const quarter = `${now.getFullYear()}-Q${Math.ceil((now.getMonth() + 1) / 3)}`;

    // Update trip
    const { data: updatedTrip, error } = await supabase
      .from('trips')
      .update({
        status: 'completed',
        end_lat: endLat,
        end_lng: endLng,
        end_address: endAddress ?? null,
        end_time: now.toISOString(),
        total_miles: Math.round(miles * 10) / 10,
        total_toll_cost: totalTollCost,
        fuel_used_gallons: Math.round(fuelUsed * 100) / 100,
        fuel_cost: Math.round(fuelCost * 100) / 100,
        mpg,
      })
      .eq('id', tripId)
      .select()
      .single();

    if (error) throw error;

    // Auto-log fuel expense
    if (fuelCost > 0) {
      await supabase.from('expenses').insert({
        user_id: user.id,
        trip_id: tripId,
        category: 'fuel',
        amount: Math.round(fuelCost * 100) / 100,
        description: `Auto-logged: ${Math.round(miles * 10) / 10} miles @ ${mpg} MPG`,
        date: now.toISOString().split('T')[0],
        state,
        miles_driven: Math.round(miles * 10) / 10,
        is_auto_logged: true,
      });
    }

    // Auto-log toll expense
    if (totalTollCost > 0) {
      await supabase.from('expenses').insert({
        user_id: user.id,
        trip_id: tripId,
        category: 'toll',
        amount: totalTollCost,
        description: `Auto-logged tolls for trip`,
        date: now.toISOString().split('T')[0],
        state,
        is_auto_logged: true,
      });
    }

    // Log IFTA mileage
    await supabase.from('ifta_mileage').insert({
      user_id: user.id,
      trip_id: tripId,
      state,
      miles: Math.round(miles * 10) / 10,
      quarter,
      year: now.getFullYear(),
    });

    return NextResponse.json({
      trip: updatedTrip,
      summary: {
        miles: Math.round(miles * 10) / 10,
        fuelCost: Math.round(fuelCost * 100) / 100,
        tollCost: totalTollCost,
        totalCost: Math.round((fuelCost + totalTollCost) * 100) / 100,
        fuelGallons: Math.round(fuelUsed * 100) / 100,
        state,
      },
    });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'Failed to end trip' },
      { status: 500 }
    );
  }
}
