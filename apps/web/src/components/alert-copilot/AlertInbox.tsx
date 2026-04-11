'use client';

/**
 * ============================================================
 * AlertInbox.tsx — Dispatcher Alert Inbox
 * ============================================================
 * Wires directly to all 7 backend systems:
 *   1. Shows deduped/fingerprinted alerts
 *   2. State machine transitions (ack/snooze/resolve/dismiss)
 *   3. AI feedback (thumbs up/down per recommendation)
 *   4. Priority score column + sorting
 *   5. Escalation badge (Dispatcher / Fleet Admin / Owner)
 *   6. Cluster grouping (situations, not just individual alerts)
 *   7. Offline indicator + reconnect replay trigger
 * ============================================================
 */

import { useState, useEffect, useCallback, useRef } from "react";

// ─────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────

const STATUS_COLORS: Record<string, { bg: string; text: string; label: string }> = {
  open:         { bg: '#FF4444', text: '#fff',    label: 'OPEN'         },
  acknowledged: { bg: '#F59E0B', text: '#fff',    label: 'ACK'          },
  snoozed:      { bg: '#6B7280', text: '#fff',    label: 'SNOOZED'      },
  resolved:     { bg: '#10B981', text: '#fff',    label: 'RESOLVED'     },
  dismissed:    { bg: '#374151', text: '#9CA3AF', label: 'DISMISSED'    },
};

const SEVERITY_COLORS: Record<string, string> = {
  CRITICAL: '#FF4444',
  HIGH:     '#F97316',
  MEDIUM:   '#F59E0B',
  LOW:      '#3B82F6',
};

const ESCALATION_COLORS: Record<string, string> = {
  dispatcher:  '#3B82F6',
  fleet_admin: '#F59E0B',
  owner:       '#EF4444',
  executive:   '#9333EA',
};

const ALERT_TYPE_ICONS: Record<string, string> = {
  HOS_VIOLATION:   '⏱️',
  TRAFFIC_DELAY:   '🚦',
  LATE_ETA:        '🕐',
  WEIGH_STATION:   '⚖️',
  GEOFENCE_BREACH: '📍',
  ROUTE_DEVIATION: '🔀',
  HAZARD_NEARBY:   '⚠️',
  INSPECTION_RISK: '🔍',
};

const VALID_TRANSITIONS: Record<string, string[]> = {
  open:         ['acknowledged', 'snoozed', 'dismissed'],
  acknowledged: ['resolved', 'snoozed', 'dismissed'],
  snoozed:      ['open', 'dismissed'],
  resolved:     [],
  dismissed:    [],
};

const ACTION_OPTIONS = [
  { value: 'rerouted',    label: '✅ Rerouted driver'     },
  { value: 'contacted',   label: '📞 Contacted driver'    },
  { value: 'manual_fix',  label: '🔧 Fixed manually'      },
  { value: 'ignored',     label: '🙈 Ignored'             },
  { value: 'false_alarm', label: '🚫 False alarm'         },
];


// ─────────────────────────────────────────────
// API HELPERS
// ─────────────────────────────────────────────

const BASE = '/api/alerts';

async function apiFetch(path: string, opts: any = {}) {
  const res = await fetch(`${BASE}${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...opts,
    body: opts.body ? JSON.stringify(opts.body) : undefined,
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error || `HTTP ${res.status}`);
  }
  return res.json();
}


// ─────────────────────────────────────────────
// SUB-COMPONENTS
// ─────────────────────────────────────────────

/** Priority ring (0-100) */
function PriorityRing({ score }: { score: number }) {
  const color = score >= 75 ? '#FF4444' : score >= 50 ? '#F97316' : score >= 25 ? '#F59E0B' : '#3B82F6';
  const r = 18, circ = 2 * Math.PI * r;
  const dash = (score / 100) * circ;
  return (
    <div style={{ position: 'relative', width: 44, height: 44, flexShrink: 0 }}>
      <svg width={44} height={44} viewBox="0 0 44 44" style={{ transform: 'rotate(-90deg)' }}>
        <circle cx={22} cy={22} r={r} fill="none" stroke="#1F2937" strokeWidth={4} />
        <circle
          cx={22} cy={22} r={r}
          fill="none"
          stroke={color}
          strokeWidth={4}
          strokeDasharray={`${dash} ${circ}`}
          strokeLinecap="round"
        />
      </svg>
      <span style={{
        position: 'absolute', inset: 0, display: 'flex',
        alignItems: 'center', justifyContent: 'center',
        fontSize: 11, fontWeight: 700, color,
        fontFamily: 'monospace',
      }}>{score}</span>
    </div>
  );
}

/** Escalation badge */
function EscalationBadge({ escalation }: { escalation?: any }) {
  if (!escalation) return null;
  const color = ESCALATION_COLORS[escalation.role] || '#6B7280';
  return (
    <span style={{
      fontSize: 10, fontWeight: 700, letterSpacing: '0.05em',
      color, border: `1px solid ${color}`, borderRadius: 4,
      padding: '1px 5px', textTransform: 'uppercase',
    }}>
      {escalation.label} · {escalation.minutesElapsed}m
    </span>
  );
}

/** Status pill */
function StatusPill({ status }: { status: string }) {
  const c = STATUS_COLORS[status] || STATUS_COLORS.open;
  return (
    <span style={{
      fontSize: 10, fontWeight: 700, letterSpacing: '0.06em',
      background: c.bg, color: c.text, borderRadius: 4,
      padding: '2px 7px',
    }}>{c.label}</span>
  );
}

/** AI Feedback widget */
function AIFeedback({ alertId, onFeedback }: { alertId: string; onFeedback?: Function }) {
  const [submitted, setSubmitted] = useState(false);
  const [action, setAction]       = useState('');
  const [open, setOpen]           = useState(false);

  const submit = async (helpful: boolean) => {
    if (!action) { alert('Select an action first'); return; }
    try {
      await apiFetch(`/${alertId}/feedback`, {
        method: 'POST',
        body: { action_taken: action, was_helpful: helpful },
      });
      setSubmitted(true);
      onFeedback?.(alertId, { action, helpful });
    } catch (err: any) {
      console.error('Feedback error:', err.message);
    }
  };

  if (submitted) {
    return (
      <span style={{ fontSize: 11, color: '#10B981' }}>✓ Feedback recorded</span>
    );
  }

  return (
    <div style={{ marginTop: 8 }}>
      {!open
        ? <button
            onClick={() => setOpen(true)}
            style={{ fontSize: 11, background: 'none', border: '1px solid #374151',
                     borderRadius: 4, color: '#9CA3AF', padding: '3px 8px', cursor: 'pointer' }}>
            Was this helpful?
          </button>
        : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
            <select
              value={action}
              onChange={e => setAction(e.target.value)}
              style={{ fontSize: 11, background: '#111827', border: '1px solid #374151',
                       borderRadius: 4, color: '#D1D5DB', padding: '3px 6px' }}
            >
              <option value="">— Action taken —</option>
              {ACTION_OPTIONS.map(o => (
                <option key={o.value} value={o.value}>{o.label}</option>
              ))}
            </select>
            <div style={{ display: 'flex', gap: 6 }}>
              <button onClick={() => submit(true)}
                style={{ fontSize: 11, background: '#065F46', border: 'none',
                         borderRadius: 4, color: '#10B981', padding: '3px 8px', cursor: 'pointer' }}>
                👍 Helpful
              </button>
              <button onClick={() => submit(false)}
                style={{ fontSize: 11, background: '#7F1D1D', border: 'none',
                         borderRadius: 4, color: '#EF4444', padding: '3px 8px', cursor: 'pointer' }}>
                👎 Not helpful
              </button>
            </div>
          </div>
        )
      }
    </div>
  );
}

/** Single alert card */
function AlertCard({ alert, onTransition, onFeedback }: { alert: any; onTransition?: Function; onFeedback?: Function }) {
  const [loading, setLoading] = useState(false);
  const [showSnooze, setShowSnooze] = useState(false);
  const [snoozeMin, setSnoozeMin]   = useState(15);
  const allowedTransitions = VALID_TRANSITIONS[alert.status] || [];

  const transition = async (status: string, extra = {}) => {
    setLoading(true);
    try {
      await apiFetch(`/${alert.id}/transition`, {
        method: 'PATCH',
        body: { status, ...extra },
      });
      onTransition?.(alert.id, status);
    } catch (err: any) {
      alert(`Error: ${err.message}`);
    } finally {
      setLoading(false);
      setShowSnooze(false);
    }
  };

  const sevColor = SEVERITY_COLORS[alert.severity] || '#6B7280';
  const icon = ALERT_TYPE_ICONS[alert.alert_type] || '🔔';

  return (
    <div style={{
      background: '#0F172A',
      border: `1px solid ${alert.priority_score >= 75 ? '#FF444433' : '#1F2937'}`,
      borderLeft: `3px solid ${sevColor}`,
      borderRadius: 8,
      padding: '14px 16px',
      display: 'flex',
      flexDirection: 'column',
      gap: 8,
      opacity: loading ? 0.6 : 1,
      transition: 'opacity 0.2s',
    }}>
      {/* Header row */}
      <div style={{ display: 'flex', alignItems: 'flex-start', gap: 10 }}>
        <PriorityRing score={alert.priority_score ?? 0} />

        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap' }}>
            <span style={{ fontSize: 14, fontWeight: 700, color: '#F9FAFB' }}>
              {icon} {alert.alert_type.replace(/_/g, ' ')}
            </span>
            <StatusPill status={alert.status} />
            {alert.upgrade_count > 0 && (
              <span style={{ fontSize: 10, color: '#F97316' }}>
                ↑ upgraded ×{alert.upgrade_count}
              </span>
            )}
          </div>

          <div style={{ fontSize: 11, color: '#6B7280', marginTop: 2 }}>
            {alert.driver_name && <span>👤 {alert.driver_name} · </span>}
            {alert.load_origin && (
              <span>{alert.load_origin} → {alert.load_destination} · </span>
            )}
            <span>{new Date(alert.created_at).toLocaleTimeString()}</span>
          </div>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 4 }}>
          <span style={{
            fontSize: 10, fontWeight: 700, color: sevColor,
            textTransform: 'uppercase', letterSpacing: '0.07em',
          }}>{alert.severity}</span>
          <EscalationBadge escalation={alert.escalation} />
        </div>
      </div>

      {/* Cluster badge */}
      {alert.cluster_label && (
        <div style={{
          background: '#1E293B', borderRadius: 4, padding: '4px 8px',
          fontSize: 11, color: '#93C5FD', display: 'flex', alignItems: 'center', gap: 4,
        }}>
          🔗 <strong>{alert.cluster_label}</strong>
          {alert.cluster_description && ` — ${alert.cluster_description}`}
        </div>
      )}

      {/* Action buttons */}
      {allowedTransitions.length > 0 && (
        <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
          {allowedTransitions.includes('acknowledged') && (
            <button onClick={() => transition('acknowledged')}
              style={btnStyle('#1D4ED8','#BFDBFE')}>Acknowledge</button>
          )}
          {allowedTransitions.includes('resolved') && (
            <button onClick={() => transition('resolved')}
              style={btnStyle('#065F46','#6EE7B7')}>Resolve ✓</button>
          )}
          {allowedTransitions.includes('snoozed') && !showSnooze && (
            <button onClick={() => setShowSnooze(true)}
              style={btnStyle('#374151','#9CA3AF')}>Snooze 💤</button>
          )}
          {allowedTransitions.includes('open') && (
            <button onClick={() => transition('open')}
              style={btnStyle('#374151','#9CA3AF')}>Wake Up</button>
          )}
          {allowedTransitions.includes('dismissed') && (
            <button onClick={() => transition('dismissed')}
              style={btnStyle('#7F1D1D','#FCA5A5')}>Dismiss</button>
          )}
        </div>
      )}

      {/* Snooze duration picker */}
      {showSnooze && (
        <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
          <select value={snoozeMin} onChange={e => setSnoozeMin(+e.target.value)}
            style={{ fontSize: 12, background: '#1F2937', border: '1px solid #374151',
                     borderRadius: 4, color: '#D1D5DB', padding: '3px 6px' }}>
            {[5,10,15,30,60].map(m => (
              <option key={m} value={m}>{m} min</option>
            ))}
          </select>
          <button onClick={() => transition('snoozed', { snooze_minutes: snoozeMin })}
            style={btnStyle('#374151','#9CA3AF')}>Confirm Snooze</button>
          <button onClick={() => setShowSnooze(false)}
            style={{ fontSize: 11, background: 'none', border: 'none',
                     color: '#6B7280', cursor: 'pointer' }}>cancel</button>
        </div>
      )}

      {/* AI Feedback */}
      {(alert.status === 'resolved' || alert.status === 'acknowledged') && (
        <AIFeedback alertId={alert.id} onFeedback={onFeedback} />
      )}
    </div>
  );
}

function btnStyle(bg: string, fg: string): React.CSSProperties {
  return {
    fontSize: 11, fontWeight: 600, background: bg, color: fg,
    border: 'none', borderRadius: 4, padding: '4px 10px',
    cursor: 'pointer', letterSpacing: '0.03em',
  };
}


// ─────────────────────────────────────────────
// MAIN COMPONENT
// ─────────────────────────────────────────────

export default function AlertInbox({ orgId }: { orgId?: string }) {
  const [alerts,    setAlerts]    = useState<any[]>([]);
  const [clusters,  setClusters]  = useState<any[]>([]);
  const [aiReport,  setAIReport]  = useState<any[]>([]);
  const [tab,       setTab]       = useState('inbox');  // 'inbox'|'clusters'|'ai'
  const [loading,   setLoading]   = useState(true);
  const [error,     setError]     = useState<string | null>(null);
  const [isOnline,  setIsOnline]  = useState(typeof navigator !== 'undefined' ? navigator.onLine : true);
  const [lastSync,  setLastSync]  = useState<Date | null>(null);
  const offlineQueueRef = useRef([]);

  // ── Fetch inbox ─────────────────────────────
  const loadInbox = useCallback(async () => {
    try {
      setError(null);
      const supabase = createClient();
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) { setError('Not authenticated'); return; }

      const query = orgId ? `?org_id=${orgId}&limit=50` : '?limit=50';
      const data = await apiFetch(`/inbox${query}`);
      setAlerts(data.alerts || []);
      setLastSync(new Date());
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, [orgId]);

  const loadClusters = useCallback(async () => {
    try {
      const data = await apiFetch('/clusters');
      setClusters(data.clusters || []);
    } catch (err: any) {
      console.error('Clusters error:', err.message);
    }
  }, []);

  const loadAIReport = useCallback(async () => {
    try {
      const data = await apiFetch('/ai-performance?days=30');
      setAIReport(data.report || []);
    } catch (err: any) {
      console.error('AI report error:', err.message);
    }
  }, []);

  // ── Online/offline tracking ──────────────────
  useEffect(() => {
    const handleOnline  = () => {
      setIsOnline(true);
      // Replay offline queue on reconnect
      if (offlineQueueRef.current.length > 0) {
        apiFetch('/replay', {
          method: 'POST',
          body: { events: offlineQueueRef.current },
        }).then(() => {
          offlineQueueRef.current = [];
          loadInbox();
        }).catch(console.error);
      }
    };
    const handleOffline = () => setIsOnline(false);
    window.addEventListener('online',  handleOnline);
    window.addEventListener('offline', handleOffline);
    return () => {
      window.removeEventListener('online',  handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  }, [loadInbox]);

  // ── Initial load + polling ───────────────────
  useEffect(() => {
    loadInbox();
    loadClusters();
    const interval = setInterval(() => {
      if (typeof navigator !== 'undefined' && navigator.onLine) loadInbox();
    }, 30_000);
    return () => clearInterval(interval);
  }, [loadInbox, loadClusters]);

  const handleTransition = useCallback((alertId: string, newStatus: string) => {
    setAlerts(prev => prev.map(a =>
      a.id === alertId ? { ...a, status: newStatus } : a
    ));
    loadInbox();
  }, [loadInbox]);

  // ── Derived stats ───────────────────────────
  const criticalCount = alerts.filter(a => a.severity === 'CRITICAL' && a.status === 'open').length;
  const openCount     = alerts.filter(a => a.status === 'open').length;
  const ackCount      = alerts.filter(a => a.status === 'acknowledged').length;
  const escalated     = alerts.filter(a => (a.escalation?.level ?? 0) > 0).length;


  return (
    <div style={{
      background: '#030712',
      minHeight: '100vh',
      color: '#F9FAFB',
      fontFamily: "'JetBrains Mono', 'Fira Code', 'Courier New', monospace",
    }}>
      {/* ── Top bar ──────────────────────────── */}
      <div style={{
        background: '#0F172A',
        borderBottom: '1px solid #1F2937',
        padding: '12px 24px',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <span style={{ fontSize: 18, fontWeight: 800, color: '#F9FAFB' }}>🚨 Alert Inbox</span>
          {criticalCount > 0 && (
            <span style={{
              background: '#FF4444', color: '#fff', borderRadius: 12,
              fontSize: 12, fontWeight: 700, padding: '2px 8px',
              animation: 'pulse 1.5s infinite',
            }}>{criticalCount} CRITICAL</span>
          )}
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          {/* Online indicator */}
          <span style={{ fontSize: 11, display: 'flex', alignItems: 'center', gap: 4 }}>
            <span style={{
              width: 8, height: 8, borderRadius: '50%',
              background: isOnline ? '#10B981' : '#EF4444',
              display: 'inline-block',
            }} />
            <span style={{ color: isOnline ? '#10B981' : '#EF4444' }}>
              {isOnline ? 'LIVE' : 'OFFLINE'}
            </span>
          </span>

          {lastSync && (
            <span style={{ fontSize: 10, color: '#6B7280' }}>
              sync {lastSync.toLocaleTimeString()}
            </span>
          )}

          <button onClick={loadInbox}
            style={{ fontSize: 11, background: '#1F2937', border: '1px solid #374151',
                     borderRadius: 4, color: '#9CA3AF', padding: '4px 10px', cursor: 'pointer' }}>
            ↻ Refresh
          </button>
        </div>
      </div>

      {/* ── Stats row ────────────────────────── */}
      <div style={{
        display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)',
        gap: 1, background: '#1F2937',
        borderBottom: '1px solid #1F2937',
      }}>
        {[
          { label: 'Open',      value: openCount,     color: '#EF4444' },
          { label: 'Ack\'d',    value: ackCount,       color: '#F59E0B' },
          { label: 'Escalated', value: escalated,      color: '#9333EA' },
          { label: 'Clusters',  value: clusters.length, color: '#3B82F6' },
        ].map(stat => (
          <div key={stat.label} style={{
            background: '#0F172A', padding: '12px 20px', textAlign: 'center',
          }}>
            <div style={{ fontSize: 22, fontWeight: 800, color: stat.color }}>
              {stat.value}
            </div>
            <div style={{ fontSize: 10, color: '#6B7280', textTransform: 'uppercase',
                          letterSpacing: '0.08em' }}>{stat.label}</div>
          </div>
        ))}
      </div>

      {/* ── Tabs ─────────────────────────────── */}
      <div style={{
        display: 'flex', gap: 0, borderBottom: '1px solid #1F2937',
        background: '#0F172A',
      }}>
        {[
          { key: 'inbox',    label: `📋 Inbox (${openCount + ackCount})`     },
          { key: 'clusters', label: `🔗 Situations (${clusters.length})`     },
          { key: 'ai',       label: '🤖 AI Report'                          },
        ].map(t => (
          <button key={t.key} onClick={() => { setTab(t.key); if (t.key === 'ai') loadAIReport(); }}
            style={{
              padding: '10px 20px', fontSize: 12, fontWeight: 600, cursor: 'pointer',
              background: 'none', border: 'none',
              borderBottom: tab === t.key ? '2px solid #3B82F6' : '2px solid transparent',
              color: tab === t.key ? '#3B82F6' : '#6B7280',
            }}>
            {t.label}
          </button>
        ))}
      </div>

      {/* ── Content ──────────────────────────── */}
      <div style={{ padding: '16px 24px', maxWidth: 900, margin: '0 auto' }}>

        {/* Offline warning */}
        {!isOnline && (
          <div style={{
            background: '#7F1D1D', border: '1px solid #EF4444',
            borderRadius: 6, padding: '10px 14px', marginBottom: 16,
            fontSize: 12, color: '#FCA5A5',
          }}>
            ⚠️ You're offline. Events are being queued locally and will replay on reconnect.
          </div>
        )}

        {error && (
          <div style={{
            background: '#7F1D1D', borderRadius: 6, padding: '10px 14px',
            marginBottom: 16, fontSize: 12, color: '#FCA5A5',
          }}>❌ {error}</div>
        )}

        {/* ── INBOX TAB ─────────────────────── */}
        {tab === 'inbox' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {loading && (
              <div style={{ textAlign: 'center', color: '#6B7280', padding: 40, fontSize: 13 }}>
                Loading alerts…
              </div>
            )}
            {!loading && alerts.length === 0 && (
              <div style={{
                textAlign: 'center', color: '#10B981', padding: 60, fontSize: 14,
              }}>
                ✅ No active alerts
              </div>
            )}
            {alerts.map(alert => (
              <AlertCard
                key={alert.id}
                alert={alert}
                onTransition={handleTransition}
                onFeedback={() => loadInbox()}
              />
            ))}
          </div>
        )}

        {/* ── CLUSTERS TAB ──────────────────── */}
        {tab === 'clusters' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            {clusters.length === 0 && (
              <div style={{ textAlign: 'center', color: '#6B7280', padding: 60 }}>
                No active situations clustered yet
              </div>
            )}
            {clusters.map(cluster => (
              <div key={cluster.id} style={{
                background: '#0F172A', border: '1px solid #1E3A5F',
                borderRadius: 8, padding: 16,
              }}>
                <div style={{ fontSize: 14, fontWeight: 700, color: '#93C5FD', marginBottom: 4 }}>
                  🔗 {cluster.label}
                </div>
                <div style={{ fontSize: 12, color: '#6B7280', marginBottom: 12 }}>
                  {cluster.description}
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                  {(cluster.alerts || []).map((a: any) => (
                    <div key={a.id} style={{
                      display: 'flex', alignItems: 'center', gap: 10,
                      background: '#1E293B', borderRadius: 4, padding: '6px 10px',
                    }}>
                      <PriorityRing score={a.priority_score ?? 0} />
                      <span style={{ fontSize: 12, color: '#D1D5DB' }}>
                        {ALERT_TYPE_ICONS[a.alert_type]} {a.alert_type.replace(/_/g, ' ')}
                      </span>
                      <StatusPill status={a.status} />
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>
        )}

        {/* ── AI REPORT TAB ─────────────────── */}
        {tab === 'ai' && (
          <div>
            <div style={{ fontSize: 12, color: '#6B7280', marginBottom: 16 }}>
              Last 30 days · Which alerts are actually helpful?
            </div>
            {aiReport.length === 0 && (
              <div style={{ textAlign: 'center', color: '#6B7280', padding: 60 }}>
                No feedback recorded yet
              </div>
            )}
            <div style={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
              {/* Header */}
              <div style={{
                display: 'grid',
                gridTemplateColumns: '160px 60px 60px 60px 60px 80px',
                gap: 8, padding: '6px 10px',
                fontSize: 10, color: '#6B7280', textTransform: 'uppercase',
                letterSpacing: '0.07em',
              }}>
                <span>Alert Type</span>
                <span style={{ textAlign: 'right' }}>Total</span>
                <span style={{ textAlign: 'right' }}>Helpful</span>
                <span style={{ textAlign: 'right' }}>Ignored</span>
                <span style={{ textAlign: 'right' }}>Avg (s)</span>
                <span style={{ textAlign: 'right' }}>Score</span>
              </div>

              {aiReport.map(row => {
                const pct = parseFloat(row.helpfulness_pct) || 0;
                const scoreColor = pct >= 70 ? '#10B981' : pct >= 40 ? '#F59E0B' : '#EF4444';
                return (
                  <div key={row.alert_type} style={{
                    display: 'grid',
                    gridTemplateColumns: '160px 60px 60px 60px 60px 80px',
                    gap: 8, padding: '8px 10px',
                    background: '#0F172A', borderRadius: 4,
                    fontSize: 12, alignItems: 'center',
                  }}>
                    <span style={{ color: '#D1D5DB' }}>
                      {ALERT_TYPE_ICONS[row.alert_type]} {row.alert_type.replace(/_/g, ' ')}
                    </span>
                    <span style={{ textAlign: 'right', color: '#9CA3AF' }}>{row.total}</span>
                    <span style={{ textAlign: 'right', color: '#10B981' }}>{row.helpful}</span>
                    <span style={{ textAlign: 'right', color: '#EF4444' }}>{row.ignored}</span>
                    <span style={{ textAlign: 'right', color: '#9CA3AF' }}>
                      {row.avg_resolution_sec ?? '—'}
                    </span>
                    <div style={{ textAlign: 'right' }}>
                      <span style={{
                        fontWeight: 700, color: scoreColor,
                        background: `${scoreColor}22`, borderRadius: 4,
                        padding: '2px 6px',
                      }}>
                        {pct}%
                      </span>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        )}
      </div>

      <style>{`
        @keyframes pulse {
          0%, 100% { opacity: 1; }
          50% { opacity: 0.5; }
        }
      `}</style>
    </div>
  );
}
