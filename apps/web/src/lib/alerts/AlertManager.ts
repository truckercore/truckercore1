// TypeScript
export type AlertKind = "slowdown" | "collision" | "fatigue";
export type AlertEvent = { kind: AlertKind; severity: "info"|"warn"|"crit"; msg: string; at: number };

type Tunables = {
  quietHours?: { start: number; end: number };
  cooldownMs?: number;
  perFleetThresholds?: Partial<Record<AlertKind, number>>;
};

export class AlertManager {
  private lastAt: Partial<Record<AlertKind, number>> = {};
  constructor(private tun: Tunables = {}) {}

  shouldNotify(ev: AlertEvent): boolean {
    const now = Date.now();
    const q = this.tun.quietHours;
    if (q) {
      const h = new Date(now).getHours();
      const quiet = q.start < q.end ? (h >= q.start && h < q.end) : (h >= q.start || h < q.end);
      if (quiet) return false;
    }
    const cooldown = this.tun.cooldownMs ?? 15000;
    if ((this.lastAt[ev.kind] ?? 0) > now - cooldown) return false;
    this.lastAt[ev.kind] = now;
    return true;
  }

  notify(ev: AlertEvent, channel: (e: AlertEvent)=>void) {
    if (this.shouldNotify(ev)) channel(ev);
  }
}
