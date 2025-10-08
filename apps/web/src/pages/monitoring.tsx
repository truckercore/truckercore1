import React from 'react';
import Head from 'next/head';
import { MonitoringDashboard } from '../components/monitoring/MonitoringDashboard';
import '../components/monitoring/MonitoringDashboard.css';

export default function MonitoringPage() {
  return (
    <>
      <Head>
        <title>Storage Monitoring • TruckerCore</title>
      </Head>
      <MonitoringDashboard />
    </>
  );
}
