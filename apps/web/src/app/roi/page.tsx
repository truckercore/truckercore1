"use client";
import React from "react";

export default function ROICalculator() {
  const [fleetSize, setFleetSize] = React.useState(50);
  const [avgDetentionHrs, setAvgDetentionHrs] = React.useState(2);
  const [incidentsPerYear, setIncidentsPerYear] = React.useState(5);

  const detentionSavings = fleetSize * 200 * (avgDetentionHrs * 0.2) * 50; // 20% reduction, $50/hr
  const incidentSavings = incidentsPerYear * 0.2 * 15000; // 20% reduction, $15k/incident
  const totalSavings = detentionSavings + incidentSavings;
  const costProPlan = 149 * 12;
  const netROI = totalSavings - costProPlan;

  return (
    <div style={{ maxWidth: 640, margin: "0 auto", padding: 48 }}>
      <h1>TruckerCore ROI Calculator</h1>
      <p style={{ marginBottom: 32 }}>Estimate your annual savings with proactive safety intelligence.</p>

      <label>
        Fleet Size (trucks):
        <input
          type="number"
          value={fleetSize}
          onChange={(e) => setFleetSize(Number(e.target.value))}
          style={{ display: "block", width: "100%", padding: 8, marginTop: 4, marginBottom: 16 }}
        />
      </label>

      <label>
        Avg Detention Hours/Week:
        <input
          type="number"
          value={avgDetentionHrs}
          onChange={(e) => setAvgDetentionHrs(Number(e.target.value))}
          style={{ display: "block", width: "100%", padding: 8, marginTop: 4, marginBottom: 16 }}
        />
      </label>

      <label>
        Incidents/Year:
        <input
          type="number"
          value={incidentsPerYear}
          onChange={(e) => setIncidentsPerYear(Number(e.target.value))}
          style={{ display: "block", width: "100%", padding: 8, marginTop: 4, marginBottom: 16 }}
        />
      </label>

      <div style={{ background: "#f5f5f5", padding: 24, borderRadius: 8, marginTop: 24 }}>
        <h3>Estimated Annual Savings</h3>
        <div style={{ fontSize: 18, marginTop: 12 }}>
          Detention Reduction: <strong>${detentionSavings.toLocaleString()}</strong>
        </div>
        <div style={{ fontSize: 18, marginTop: 8 }}>
          Incident Reduction: <strong>${incidentSavings.toLocaleString()}</strong>
        </div>
        <div style={{ fontSize: 24, marginTop: 16, fontWeight: 700 }}>
          Total Savings: <span style={{ color: "#2E7D32" }}>${totalSavings.toLocaleString()}</span>
        </div>
        <div style={{ fontSize: 18, marginTop: 8, opacity: 0.7 }}>
          TruckerCore Pro Cost: ${costProPlan.toLocaleString()}/year
        </div>
        <div style={{ fontSize: 24, marginTop: 12, fontWeight: 700 }}>
          Net ROI: <span style={{ color: netROI > 0 ? "#2E7D32" : "#C62828" }}>${netROI.toLocaleString()}</span>
        </div>
      </div>

      <button
        style={{
          marginTop: 24,
          width: "100%",
          padding: 16,
          fontSize: 18,
          fontWeight: 700,
          background: "#667eea",
          color: "#fff",
          border: "none",
          borderRadius: 8,
          cursor: "pointer",
        }}
        onClick={() => (window.location.href = "/upgrade")}
      >
        Start Free Trial
      </button>
    </div>
  );
}
