// TypeScript
import type { AlertKind } from "./AlertManager";

export type Feedback = { alertKind: AlertKind; ts: number; verdict: "useful"|"false_positive"; note?: string };

export class FeedbackBuffer {
  private buf: Feedback[] = [];
  push(f: Feedback) { this.buf.push(f); if (this.buf.length > 20) this.flush(); }
  async flush() {
    const chunk = this.buf.splice(0, this.buf.length);
    if (!chunk.length) return;
    await fetch("/api/alert-feedback", { method:"POST", headers:{ "content-type":"application/json" }, body: JSON.stringify({ items: chunk })});
  }
}
