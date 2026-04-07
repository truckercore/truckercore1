"use client";
import React from "react";
import { createClient } from "@supabase/supabase-js";

const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);

type Integration = {
  id: string;
  name: string;
  slug: string;
  category: string;
  description: string;
  logo_url: string | null;
  active: boolean;
};

export default function IntegrationsPage() {
  const [integrations, setIntegrations] = React.useState<Integration[]>([]);

  const trackEvent = async (integrationId: string, eventType: string) => {
    try {
      const orgId = typeof window !== "undefined" ? window.localStorage.getItem("org_id") : null;
      if (!orgId) return;
      await fetch("/api/integrations/track", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ orgId, integrationId, eventType }),
      });
    } catch {}
  };

  React.useEffect(() => {
    (async () => {
      const { data } = await supabase.from("integrations_catalog").select("*").eq("active", true);
      if (data) setIntegrations(data as any);
    })();
  }, []);

  React.useEffect(() => {
    if (integrations.length) {
      integrations.forEach((i) => trackEvent(i.id, "viewed"));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [integrations]);

  return (
    <div style={{ padding: 24 }}>
      <h1>Integrations</h1>
      <p style={{ marginBottom: 24 }}>Connect your ELD, TMS, insurance, and compliance tools.</p>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(280px, 1fr))", gap: 16 }}>
        {integrations.map((i) => (
          <div key={i.id} className="card" style={{ padding: 16 }}>
            {i.logo_url && <img src={i.logo_url} alt={i.name} style={{ height: 40, marginBottom: 8 }} />}
            <h3 style={{ marginBottom: 8 }}>{i.name}</h3>
            <div style={{ fontSize: 12, opacity: 0.7, marginBottom: 8 }}>{i.category.toUpperCase()}</div>
            <p style={{ fontSize: 14, marginBottom: 12 }}>{i.description}</p>
            <button
              onClick={() => {
                trackEvent(i.id, "connected");
                alert(`Connect ${i.name} (coming soon)`);
              }}
            >
              Connect
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}
