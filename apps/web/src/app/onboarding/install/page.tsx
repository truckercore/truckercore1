"use client";
import React from "react";
import { useSearchParams } from "next/navigation";

export default function Install() {
  const sp = useSearchParams();
  const org = sp.get("org")!;
  const role = sp.get("role")!;

  const [installPrompt, setInstallPrompt] = React.useState<any>(null);
  const [token, setToken] = React.useState<string | null>(null);
  const [error, setError] = React.useState<string | null>(null);

  React.useEffect(() => {
    const handler = (e: any) => { e.preventDefault(); setInstallPrompt(e); };
    // @ts-ignore
    window.addEventListener("beforeinstallprompt", handler);
    return () => window.removeEventListener("beforeinstallprompt", handler);
  }, []);

  const fp = () => {
    const nav = navigator as any;
    const ua = navigator.userAgent;
    const lang = navigator.language;
    const mem = nav.deviceMemory || "";
    const cores = nav.hardwareConcurrency || "";
    return btoa([ua, lang, mem, cores].join("|"));
  };

  const issue = async () => {
    setError(null);
    const r = await fetch("/api/issue-install-license", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ org_id: org, role, device_fingerprint: fp() }),
    });
    const j = await r.json();
    if (!r.ok) { setError(j?.message || "Failed to issue license"); return; }
    setToken(j.token);
    try {
      localStorage.setItem("offline_entitlement", JSON.stringify({ token: j.token, org_id: org, role, exp: Date.now() + 24*3600*1000 }));
    } catch {}
  };

  const installPwa = async () => {
    if (installPrompt) {
      installPrompt.prompt();
      await installPrompt.userChoice;
      setInstallPrompt(null);
    } else {
      alert("Use your browser's Install or Add to Desktop option.");
    }
  };

  return (
    <div style={{ padding: 24 }}>
      <h1>Install</h1>
      <p>Install as a Desktop App for one-click access and offline support.</p>
      <div style={{ display: "flex", gap: 12 }}>
        <button onClick={installPwa}>Install as Desktop App</button>
        <a href="https://www.pwabuilder.com" target="_blank" rel="noreferrer">Optional: Download OS installer</a>
      </div>
      <h3 style={{ marginTop: 16 }}>License</h3>
      <button onClick={issue}>Issue device license</button>
      {token && <div style={{ wordBreak: "break-all", marginTop: 8 }}>Issued</div>}
      {error && <div style={{ color: "tomato" }}>{error}</div>}
    </div>
  );
}
