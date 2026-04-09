import { useGeofenceAlerts, GeofenceAlert } from "@/hooks/useGeofenceAlerts";
import { useRouter } from "next/navigation"; // or react-router equivalent

const SEVERITY_STYLES: Record<string, { card: string; label: string }> = {
  critical: {
    card:  "bg-red-500/10 border-red-500/30",
    label: "text-red-400",
  },
  warning: {
    card:  "bg-yellow-500/10 border-yellow-500/30",
    label: "text-yellow-300",
  },
  info: {
    card:  "bg-white/4 border-white/9",
    label: "text-white/50",
  },
};

interface AlertCardProps {
  alert: GeofenceAlert;
  onAck: (id: string) => void;
  onReroute: (alert: GeofenceAlert) => void;
  onMessage: (alert: GeofenceAlert) => void;
  isNew: boolean;
}

function AlertCard({ alert, onAck, onReroute, onMessage, isNew }: AlertCardProps) {
  const styles = SEVERITY_STYLES[alert.severity] ?? SEVERITY_STYLES.info;

  return (
    <div
      className={`rounded-xl px-3 py-2.5 border transition-opacity ${styles.card} ${
        alert.acknowledged ? "opacity-40" : ""
      }`}
    >
      <div className="flex justify-between items-start gap-2">
        <div className="flex items-center gap-2">
          <span className={`text-[10px] font-semibold uppercase tracking-wider ${styles.label}`}>
            {alert.type.replace(/_/g, " ")}
          </span>
          {isNew && (
            <span className="text-[9px] bg-red-500 text-white px-1.5 py-px rounded font-semibold">
              NEW
            </span>
          )}
        </div>
        <span className="text-[10px] text-white/30 whitespace-nowrap">
          {new Date(alert.created_at).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}
        </span>
      </div>

      <p className="text-xs text-white/80 mt-1">
        {alert.driver_name} —{" "}
        <span className="text-white/45">{alert.zone_name}</span>
      </p>

      {alert.eta_delay && alert.eta_delay > 0 && (
        <p className="text-[11px] text-yellow-300 mt-1">
          +{alert.eta_delay} min ETA delay
        </p>
      )}

      {!alert.acknowledged ? (
        <div className="flex gap-2 mt-2">
          <button
            onClick={() => onAck(alert.id)}
            className="text-[10px] px-2 py-1 rounded border border-green-500/35 text-green-400 hover:bg-green-500/10 transition-colors"
          >
            Acknowledge
          </button>
          <button
            onClick={() => onReroute(alert)}
            className="text-[10px] px-2 py-1 rounded border border-blue-500/35 text-blue-400 hover:bg-blue-500/10 transition-colors"
          >
            Reroute
          </button>
          <button
            onClick={() => onMessage(alert)}
            className="text-[10px] px-2 py-1 rounded border border-white/15 text-white/50 hover:bg-white/5 transition-colors"
          >
            Message
          </button>
        </div>
      ) : (
        <p className="text-[10px] text-white/25 mt-2">Acknowledged</p>
      )}
    </div>
  );
}

interface Props {
  orgId: string;
}

export default function GeofenceAlertsPanel({ orgId }: Props) {
  const router = useRouter();
  const { alerts, stats, acknowledge, loading } = useGeofenceAlerts(orgId);

  const handleReroute = (alert: GeofenceAlert) => {
    acknowledge(alert.id);
    router.push(`/fleet/reroute?driver=${alert.driver_id}&alert=${alert.id}`);
  };

  const handleMessage = (alert: GeofenceAlert) => {
    router.push(`/fleet/dispatch?driver=${alert.driver_id}&prefill=route-alert`);
  };

  if (loading) return null;

  return (
    <div className="bg-[#0f1117] border border-white/10 rounded-xl p-4 space-y-4">
      {/* Header */}
      <div className="flex items-center gap-2">
        <span className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
        <h3 className="text-xs font-medium text-white/80 uppercase tracking-wider">
          Ops Command Center
        </h3>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-3 gap-2">
        <div className="bg-white/4 rounded-lg p-2 text-center">
          <p className={`text-base font-medium ${stats.critical > 0 ? "text-red-400" : "text-white/50"}`}>
            {stats.critical}
          </p>
          <p className="text-[10px] text-white/35 mt-0.5">Critical</p>
        </div>
        <div className="bg-white/4 rounded-lg p-2 text-center">
          <p className={`text-base font-medium ${stats.warning > 0 ? "text-yellow-400" : "text-white/50"}`}>
            {stats.warning}
          </p>
          <p className="text-[10px] text-white/35 mt-0.5">Warnings</p>
        </div>
        <div className="bg-white/4 rounded-lg p-2 text-center">
          <p className={`text-base font-medium ${stats.resolved > 0 ? "text-green-400" : "text-white/50"}`}>
            {stats.resolved}
          </p>
          <p className="text-[10px] text-white/35 mt-0.5">Resolved</p>
        </div>
      </div>

      {/* Alert feed */}
      <div className="space-y-2 max-h-[480px] overflow-y-auto pr-0.5">
        {alerts.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-10 text-white/25 text-xs gap-2">
            <svg width="28" height="28" viewBox="0 0 24 24" fill="none">
              <path d="M12 2a10 10 0 100 20A10 10 0 0012 2z" stroke="currentColor" strokeWidth="1.2"/>
              <path d="M9 12l2 2 4-4" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round"/>
            </svg>
            No active alerts
          </div>
        ) : (
          alerts.map((alert, i) => (
            <AlertCard
              key={alert.id}
              alert={alert}
              isNew={i === 0}
              onAck={acknowledge}
              onReroute={handleReroute}
              onMessage={handleMessage}
            />
          ))
        )}
      </div>
    </div>
  );
}
