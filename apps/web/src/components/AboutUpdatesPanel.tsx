import React from "react";

declare global {
  interface Window {
    __TAURI__?: {
      invoke: (cmd: string, args?: any) => Promise<any>;
      event: { listen: (evt: string, cb: (e: any) => void) => Promise<() => void> };
    };
  }
}

const isTauri = typeof window !== "undefined" && !!window.__TAURI__;

export function AboutUpdatesPanel(props: { appVersion?: string; webBuild?: string }) {
  const [status, setStatus] = React.useState<string>("Idle");

  React.useEffect(() => {
    if (!isTauri) return;
    let unsubs: Array<() => void> = [];
    const hook = async () => {
      const e = window.__TAURI__!;
      unsubs.push(await e.event.listen("tauri://update-available", () => setStatus("Update available; downloading…")));
      unsubs.push(await e.event.listen("tauri://update-download-progress", (_ev) => {
        setStatus("Downloading update…");
      }));
      unsubs.push(await e.event.listen("tauri://update-installed", () => setStatus("Update installed. Restart to apply.")));
      unsubs.push(await e.event.listen("tauri://update-status", (ev) => setStatus(String((ev as any)?.payload || "Checking…"))));
    };
    hook().catch(() => {});
    return () => { unsubs.forEach((u) => u()); };
  }, []);

  const check = async () => {
    if (!isTauri) {
      setStatus("Not running in desktop shell.");
      return;
    }
    setStatus("Checking…");
    try {
      await window.__TAURI__!.invoke("app_check_updates");
      setStatus("Requested updater; watch for prompts.");
    } catch (e: any) {
      setStatus(`Error: ${e?.toString?.() || "failed"}`);
    }
  };

  return (
    <div className="card" style={{ maxWidth: 520 }}>
      <div className="card-header">About TruckerCore</div>
      <div className="card-body">
        <div>Shell version: {props.appVersion || "unknown"}</div>
        <div>Web build: {props.webBuild || "live"}</div>
        <div style={{ marginTop: 12 }}>
          <button className="btn btn-primary" onClick={check}>Check for updates</button>
          <div style={{ marginTop: 8, fontSize: 12, opacity: 0.8 }}>{status}</div>
        </div>
      </div>
    </div>
  );
}
