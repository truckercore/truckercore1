'use client';

import React from 'react';
import { OwnerOperatorDashboard } from '../../components/OwnerOperatorDashboard';

export default function Page() {
  return (
    <OwnerOperatorDashboard
      operatorId="OO-001"
      operatorName="J&M Trucking LLC"
      mcNumber="123456"
    />
  );
}
