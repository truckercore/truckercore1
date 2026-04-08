'use client';
export const dynamic = 'force-dynamic';

import React from 'react';
import { DriverDashboard } from '@/components/DriverDashboard';
import { DashboardNavigation } from '@/components/DashboardNavigation';

export default function DriverDashboardPage() {
  return (
    <div>
      <DashboardNavigation />
      <DriverDashboard
        driverName="James Wilson"
        vehicleId="TC-101"
        isPremium={false}
      />
    </div>
  );
}
