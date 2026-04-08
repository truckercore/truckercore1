'use client';
export const dynamic = 'force-dynamic';
export const runtime = 'edge';

import React from 'react';
import { DriverDashboard } from '@/components/DriverDashboard';
import { DashboardNavigation } from '@/components/DashboardNavigation';

export default function DriverDashboardPage() {
  return (
    <div>
      <DashboardNavigation />
      <DriverDashboard
        driverName="John Doe"
        vehicleId="TRK-101"
        isPremium={false}
      />
    </div>
  );
}
