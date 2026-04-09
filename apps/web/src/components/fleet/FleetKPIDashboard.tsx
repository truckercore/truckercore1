'use client';

import { useState, useEffect, useMemo } from 'react';
import { LineChart, Line, ResponsiveContainer, Tooltip } from 'recharts';

// ─── Formatters ──────────────────────────────────────────────────────────────
const currency = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD',
  maximumFractionDigits: 0,
});
const fmtPct = (n: number) => `${Math.round(n)}%`;
const cents = (c: number) => c / 100;

// ─── Types ──────────────────────────────────────────────────────────────────
interface KPI {
  totalTrucks: number;
  activeTrucks: number;
  idleTrucks: number;
  offlineTrucks: number;
  totalDrivers: number;
  driversOnDuty: number;
  activeLoads: number;
  delayedLoads: number;
  completedLoads: number;
  onTimePct: number;
  loadUtilizationPct: number;
  totalMiles: number;
  avgMPG: number;
  baselineMPG: number;
  revenueCents: number;
  fuelCostCents: number;
  maintenanceCostCents: number;
  revenueTrend: Array<{ day: string; v: number }>;
}

// ─── Simulated data fetcher ───────────────────────────────────────────────────
// Replace with Supabase / API route:
//   const { data } = await supabase.rpc('get_fleet_kpi', { org_id: orgId });
function useFleetKPI(orgId: string, tick: number) {
  const [state, setState] = useState<{ loading: boolean; kpi: KPI | null }>({
    loading: true,
    kpi: null,
  });

  useEffect(() => {
    setState((s) => ({ ...s, loading: true }));
    const t = setTimeout(() => {
      setState({
        loading: false,
        kpi: {
          totalTrucks: 14,
          activeTrucks: 9,
          idleTrucks: 3,
          offlineTrucks: 2,
          totalDrivers: 12,
          driversOnDuty: 8,
          activeLoads: 7,
          delayedLoads: 2,
          completedLoads: 41,
          onTimePct: 78,
          loadUtilizationPct: 64,
          totalMiles: 18240,
          avgMPG: 5.9,
          baselineMPG: 6.5,
          revenueCents: 8430000,
          fuelCostCents: 1870000,
          maintenanceCostCents: 420000,
          revenueTrend: [
            { day: 'Mon', v: 9200 },
            { day: 'Tue', v: 11400 },
            { day: 'Wed', v: 8900 },
            { day: 'Thu', v: 13100 },
            { day: 'Fri', v: 12800 },
            { day: 'Sat', v: 7600 },
            { day: 'Sun', v: 8430 },
          ],
        },
      });
    }, 700);
    return () => clearTimeout(t);
  }, [orgId, tick]);

  return state;
}

// ─── Primitives ───────────────────────────────────────────────────────────────
function Card({ children, style }: { children: React.ReactNode; style?: React.CSSProperties }) {
  return (
    <div
      style={{
        background: 'var(--color-background-primary)',
        border: '0.5px solid var(--color-border-tertiary)',
        borderRadius: 'var(--border-radius-lg)',
        padding: '1rem 1.25rem',
        ...style,
      }}
    >
      {children}
    </div>
  );
}

function MetricCard({
  label,
  value,
  sub,
  valueColor,
}: {
  label: string;
  value: string | number;
  sub?: string;
  valueColor?: string;
}) {
  return (
    <div
      style={{
        background: 'var(--color-background-secondary)',
        borderRadius: 'var(--border-radius-md)',
        padding: '1rem',
      }}
    >
      <p style={{ fontSize: 12, color: 'var(--color-text-secondary)', margin: '0 0 6px', fontWeight: 400 }}>
        {label}
      </p>
      <p
        style={{
          fontSize: 22,
          fontWeight: 500,
          margin: '0 0 3px',
          color: valueColor || 'var(--color-text-primary)',
          fontFamily: 'var(--font-mono)',
        }}
      >
        {value}
      </p>
      {sub && <p style={{ fontSize: 11, color: 'var(--color-text-tertiary)', margin: 0 }}>{sub}</p>}
    </div>
  );
}

function Bar({ value, max, colorVar }: { value: number; max: number; colorVar: string }) {
  const pct = Math.min((value / Math.max(max, 1)) * 100, 100);
  return (
    <div
      style={{
        height: 5,
        borderRadius: 3,
        background: 'var(--color-border-tertiary)',
        overflow: 'hidden',
      }}
    >
      <div
        style={{
          height: '100%',
          width: `${pct}%`,
          background: colorVar,
          borderRadius: 3,
          transition: 'width 0.5s ease',
        }}
      />
    </div>
  );
}

function SectionLabel({ children }: { children: React.ReactNode }) {
  return (
    <p
      style={{
        fontSize: 10,
        fontWeight: 500,
        letterSpacing: '0.1em',
        textTransform: 'uppercase',
        color: 'var(--color-text-tertiary)',
        margin: '0 0 14px',
      }}
    >
      {children}
    </p>
  );
}

function Skeleton({ h }: { h: number }) {
  return (
    <div
      style={{
        height: h,
        background: 'var(--color-background-secondary)',
        borderRadius: 'var(--border-radius-md)',
        animation: 'pulse 1.5s ease-in-out infinite',
      }}
    />
  );
}

// ─── Main component ───────────────────────────────────────────────────────────
export default function FleetKPIDashboard({ orgId = 'demo' }: { orgId?: string }) {
  const [tick, setTick] = useState(0);
  const [lastUpdated, setLastUpdated] = useState(new Date());

  const { kpi, loading } = useFleetKPI(orgId, tick);

  const handleRefresh = () => {
    setTick((n) => n + 1);
    setLastUpdated(new Date());
  };

  // All derived values computed once — no repeated inline math
  const d = useMemo(() => {
    if (!kpi) return null;
    const truckCount = Math.max(kpi.totalTrucks, 1);
    const netCents = kpi.revenueCents - kpi.fuelCostCents - kpi.maintenanceCostCents;
    const idlePct = (kpi.idleTrucks / truckCount) * 100;
    // revenuePerTruck derived client-side, not stored separately in DB
    const revenuePerTruckCents = Math.round(kpi.revenueCents / truckCount);
    const mpgSlipped = kpi.avgMPG < kpi.baselineMPG * 0.95;
    return { truckCount, netCents, idlePct, revenuePerTruckCents, mpgSlipped };
  }, [kpi]);

  // Action items rendered conditionally — no static cards
  const actions = useMemo(() => {
    if (!kpi || !d) return [];
    const items = [];
    if (kpi.delayedLoads > 0)
      items.push({
        sev: 'danger' as const,
        title: `${kpi.delayedLoads} delayed load${kpi.delayedLoads > 1 ? 's' : ''}`,
        body: 'Review route risk and reassign if needed.',
      });
    if (kpi.idleTrucks > 0)
      items.push({
        sev: 'warning' as const,
        title: `${kpi.idleTrucks} of ${d.truckCount} trucks idle`,
        body: 'Match available capacity with open loads.',
      });
    if (d.mpgSlipped)
      items.push({
        sev: 'info' as const,
        title: `MPG below baseline — ${kpi.avgMPG.toFixed(1)} vs ${kpi.baselineMPG}`,
        body: 'Investigate route mix, idle time, and driving patterns.',
      });
    return items;
  }, [kpi, d]);

  const sevStyle = {
    danger: {
      bg: 'var(--color-background-danger)',
      border: 'var(--color-border-danger)',
      title: 'var(--color-text-danger)',
    },
    warning: {
      bg: 'var(--color-background-warning)',
      border: 'var(--color-border-warning)',
      title: 'var(--color-text-warning)',
    },
    info: {
      bg: 'var(--color-background-info)',
      border: 'var(--color-border-info)',
      title: 'var(--color-text-info)',
    },
  };

  // ── Loading state ────────────────────────────────────────────────────────────
  if (loading) {
    return (
      <div style={{ padding: '1rem 0', display: 'flex', flexDirection: 'column', gap: 12 }}>
        <style>{`@keyframes pulse { 0%,100% { opacity:1 } 50% { opacity:.4 } }`}</style>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0,1fr))', gap: 12 }}>
          {[...Array(4)].map((_, i) => <Skeleton key={i} h={80} />)}
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, minmax(0,1fr))', gap: 12 }}>
          <Skeleton h={280} />
          <Skeleton h={280} />
        </div>
        <Skeleton h={80} />
      </div>
    );
  }

  if (!kpi || !d) return null;

  const onTimeColor =
    kpi.onTimePct >= 85
      ? 'var(--color-text-success)'
      : kpi.onTimePct >= 70
      ? 'var(--color-text-warning)'
      : 'var(--color-text-danger)';

  // ── Render ───────────────────────────────────────────────────────────────────
  return (
    <div style={{ padding: '1rem 0', fontFamily: 'var(--font-sans)' }}>
      <h2 className="sr-only">
        Fleet KPI dashboard — fleet status, operations, financials, and action items
      </h2>

      {/* Header */}
      <div
        style={{
          display: 'flex',
          alignItems: 'flex-start',
          justifyContent: 'space-between',
          marginBottom: 24,
        }}
      >
        <div>
          <h2 style={{ margin: 0, fontSize: 18, fontWeight: 500 }}>Fleet KPI dashboard</h2>
          <p style={{ margin: '3px 0 0', fontSize: 12, color: 'var(--color-text-tertiary)' }}>
            Updated {lastUpdated.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
          </p>
        </div>
        <button onClick={handleRefresh} style={{ fontSize: 13 }}>
          Refresh
        </button>
      </div>

      {/* ── Fleet status ── */}
      <SectionLabel>Fleet status</SectionLabel>
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(4, minmax(0,1fr))',
          gap: 10,
          marginBottom: 20,
        }}
      >
        <MetricCard
          label="Total trucks"
          value={kpi.totalTrucks}
          sub={`${kpi.activeTrucks} active · ${kpi.offlineTrucks} offline`}
        />
        <MetricCard
          label="Active loads"
          value={kpi.activeLoads}
          sub={`${kpi.completedLoads} completed this period`}
        />
        <MetricCard label="Drivers on duty" value={kpi.driversOnDuty} sub={`of ${kpi.totalDrivers} total`} />
        <MetricCard
          label="On-time rate"
          value={fmtPct(kpi.onTimePct)}
          sub="last 30 days"
          valueColor={onTimeColor}
        />
      </div>

      {/* ── Two-column body ── */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(2, minmax(0,1fr))',
          gap: 12,
          marginBottom: 12,
        }}
      >
        {/* Operations */}
        <Card>
          <SectionLabel>Operations</SectionLabel>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
            <div>
              <div
                style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  fontSize: 13,
                  marginBottom: 7,
                }}
              >
                <span style={{ color: 'var(--color-text-secondary)' }}>Load utilization</span>
                <span style={{ fontWeight: 500 }}>{fmtPct(kpi.loadUtilizationPct)}</span>
              </div>
              <Bar value={kpi.loadUtilizationPct} max={100} colorVar="#185FA5" />
            </div>

            <div>
              <div
                style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  fontSize: 13,
                  marginBottom: 7,
                }}
              >
                <span style={{ color: 'var(--color-text-secondary)' }}>
                  Idle truck share — {kpi.idleTrucks} of {d.truckCount}
                </span>
                <span
                  style={{
                    fontWeight: 500,
                    color: d.idlePct > 30 ? 'var(--color-text-warning)' : 'var(--color-text-primary)',
                  }}
                >
                  {fmtPct(d.idlePct)}
                </span>
              </div>
              <Bar value={kpi.idleTrucks} max={d.truckCount} colorVar={d.idlePct > 30 ? '#BA7517' : '#888780'} />
            </div>

            <div>
              <div
                style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  fontSize: 13,
                  marginBottom: 7,
                }}
              >
                <span style={{ color: 'var(--color-text-secondary)' }}>Avg MPG vs baseline</span>
                <span
                  style={{
                    fontWeight: 500,
                    color: d.mpgSlipped ? 'var(--color-text-danger)' : 'var(--color-text-success)',
                  }}
                >
                  {kpi.avgMPG.toFixed(1)} / {kpi.baselineMPG}
                </span>
              </div>
              <Bar value={kpi.avgMPG} max={kpi.baselineMPG} colorVar={d.mpgSlipped ? '#A32D2D' : '#3B6D11'} />
            </div>

            <div>
              <p
                style={{
                  fontSize: 12,
                  color: 'var(--color-text-secondary)',
                  margin: '0 0 8px',
                }}
              >
                Revenue trend — 7 days
              </p>
              <div style={{ height: 64 }}>
                <ResponsiveContainer width="100%" height="100%">
                  <LineChart data={kpi.revenueTrend}>
                    <Line type="monotone" dataKey="v" stroke="#185FA5" strokeWidth={2} dot={false} />
                    <Tooltip
                      formatter={(v: number) => [currency.format(v), 'Revenue']}
                      labelStyle={{ fontSize: 11 }}
                      contentStyle={{
                        fontSize: 12,
                        background: 'var(--color-background-primary)',
                        border: '0.5px solid var(--color-border-secondary)',
                        borderRadius: 6,
                      }}
                    />
                  </LineChart>
                </ResponsiveContainer>
              </div>
            </div>
          </div>
        </Card>

        {/* Financials — revenue green, costs red, neutral for ratios */}
        <Card>
          <SectionLabel>Financials</SectionLabel>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {[
              {
                label: 'Total revenue',
                value: currency.format(cents(kpi.revenueCents)),
                color: 'var(--color-text-success)',
              },
              {
                label: 'Net margin',
                value: currency.format(cents(d.netCents)),
                color: d.netCents >= 0 ? 'var(--color-text-success)' : 'var(--color-text-danger)',
              },
              {
                label: 'Fuel cost',
                value: currency.format(cents(kpi.fuelCostCents)),
                color: 'var(--color-text-danger)',
              },
              {
                label: 'Maintenance cost',
                value: currency.format(cents(kpi.maintenanceCostCents)),
                color: 'var(--color-text-danger)',
              },
              {
                label: 'Revenue per truck',
                // Derived client-side from revenueCents / truckCount
                value: currency.format(cents(d.revenuePerTruckCents)),
                color: 'var(--color-text-primary)',
              },
            ].map((row) => (
              <div
                key={row.label}
                style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                  padding: '10px 12px',
                  borderRadius: 'var(--border-radius-md)',
                  background: 'var(--color-background-secondary)',
                  fontSize: 13,
                }}
              >
                <span style={{ color: 'var(--color-text-secondary)' }}>{row.label}</span>
                <span
                  style={{
                    fontWeight: 500,
                    color: row.color,
                    fontFamily: 'var(--font-mono)',
                  }}
                >
                  {row.value}
                </span>
              </div>
            ))}
          </div>
        </Card>
      </div>

      {/* ── Conditional action items ── */}
      {actions.length > 0 ? (
        <Card>
          <SectionLabel>Action items — {actions.length} open</SectionLabel>
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: `repeat(${Math.min(actions.length, 3)}, minmax(0,1fr))`,
              gap: 10,
            }}
          >
            {actions.map((item, i) => {
              const s = sevStyle[item.sev];
              return (
                <div
                  key={i}
                  style={{
                    padding: '12px 14px',
                    borderRadius: 'var(--border-radius-md)',
                    border: `0.5px solid ${s.border}`,
                    background: s.bg,
                  }}
                >
                  <p
                    style={{
                      margin: '0 0 4px',
                      fontSize: 13,
                      fontWeight: 500,
                      color: s.title,
                    }}
                  >
                    {item.title}
                  </p>
                  <p style={{ margin: 0, fontSize: 12, color: 'var(--color-text-secondary)' }}>{item.body}</p>
                </div>
              );
            })}
          </div>
        </Card>
      ) : (
        <Card>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div
              style={{
                width: 8,
                height: 8,
                borderRadius: '50%',
                background: 'var(--color-text-success)',
                flexShrink: 0,
              }}
            />
            <p style={{ margin: 0, fontSize: 13, color: 'var(--color-text-secondary)' }}>
              No action items — fleet is operating within normal parameters.
            </p>
          </div>
        </Card>
      )}
    </div>
  );
}
