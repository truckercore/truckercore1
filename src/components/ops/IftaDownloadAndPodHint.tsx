"use client";
import React from 'react';

export function IftaDownloadAndPodHint({ queuedCount = 0 }: { queuedCount?: number }) {
  const url = `${process.env.NEXT_PUBLIC_FUNCTIONS_URL}/generate-ifta-report?quarter=2025-07-01&org_id=00000000-0000-0000-0000-0000000AA001`;
  return (
    <div className="flex items-center gap-3">
      <button
        className="px-3 py-2 rounded-xl border"
        onClick={() => window.open(url, '_blank')}
      >
        Download IFTA CSV
      </button>
      <div className="text-xs opacity-70">
        PoD uploads queued: {queuedCount}
      </div>
    </div>
  );
}
