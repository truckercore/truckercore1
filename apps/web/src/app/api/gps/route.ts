import { NextResponse } from 'next/server';

export async function GET() {
  // Real-time GPS data fetch logic would go here
  return NextResponse.json({
    trucks: [
      {
        vehicle_id: 'TRK-101',
        driver_name: 'John Doe',
        latitude: 40.7128,
        longitude: -74.0060,
        speed_mph: 65,
        heading: 90,
        status: 'en_route',
      },
    ]
  });
}
