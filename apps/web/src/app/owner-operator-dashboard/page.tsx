'use client';

import React from 'react';
import { OwnerOperatorDashboard } from '../../components/OwnerOperatorDashboard';
import { DashboardNavigation } from '../../components/DashboardNavigation';

export default function Page() {
  return (
    <div>
      <DashboardNavigation />
      <OwnerOperatorDashboard
        operatorId="OO-001"
        operatorName="J&M Trucking LLC"
        mcNumber="123456"
      />
    </div>
  );
}
