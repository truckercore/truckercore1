'use client';

import React from 'react';
import { FleetManagerDashboard } from '../../components/FleetManagerDashboard';

export default function Page() {
  return (
    <FleetManagerDashboard
      fleetName="Premier Transportation Services"
      managerId="FM-001"
    />
  );
}
