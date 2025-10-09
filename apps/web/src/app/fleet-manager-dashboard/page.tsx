'use client';

import React from 'react';
import { FleetManagerDashboard } from '../../components/FleetManagerDashboard';
import { DashboardNavigation } from '../../components/DashboardNavigation';

export default function Page() {
  return (
    <div>
      <DashboardNavigation />
      <FleetManagerDashboard
        fleetName="Premier Transportation Services"
        managerId="FM-001"
      />
    </div>
  );
}
