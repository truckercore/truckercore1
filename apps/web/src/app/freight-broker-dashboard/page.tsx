'use client';

import React from 'react';
import FreightBrokerDashboard from '../../components/FreightBrokerDashboard';
import { DashboardNavigation } from '../../components/DashboardNavigation';

export default function Page() {
  return (
    <div>
      <DashboardNavigation />
      <FreightBrokerDashboard />
    </div>
  );
}
