'use client';

import React from 'react';
import { useParams } from 'next/navigation';
import { fleetDb } from '@/services/storage/FleetStorage';
import type { WorkOrder } from '@/types/fleet.types';

export default function WorkOrderDetails() {
  const params = useParams();
  const fleetId = params?.fleetId as string;
  const orderId = params?.orderId as string;
  const [wo, setWo] = React.useState<WorkOrder | null>(null);

  React.useEffect(() => {
    let active = true;
    (async () => {
      const found = await fleetDb.workOrders.get(orderId as any);
      if (active) setWo(found as any);
    })();
    return () => { active = false; };
  }, [orderId]);

  if (!wo) return <div style={{ padding: 16 }}><h3>Work Order not found</h3></div>;

  return (
    <div style={{ padding: 16 }}>
      <h2>Work Order {wo.id}</h2>
      <p>Fleet: {fleetId}</p>
      <p>Vehicle: {wo.vehicleId}</p>
      <p>Status: {wo.status}</p>
      <p>Priority: {wo.priority}</p>
      {wo.title && <p>Title: {wo.title}</p>}
      {wo.description && <p>Description: {wo.description}</p>}
    </div>
  );
}
