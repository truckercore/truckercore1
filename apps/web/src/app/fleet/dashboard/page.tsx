'use client';

import React from 'react';
import FleetManagerDashboard from '../../../components/FleetManagerDashboard';

export default function FleetDashboardPage() {
  // In a real app, derive from session/tenant
  const organizationId = 'org-1';
  return <FleetManagerDashboard managerId="FM-ORG" fleetName="Fleet Dashboard" /> as any;
}
