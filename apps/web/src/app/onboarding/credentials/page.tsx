"use client";
import React from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { createClientComponentClient } from "@supabase/auth-helpers-nextjs";

export default function Credentials() {
  const sp = useSearchParams();
  const role = sp.get("role") as string;
  const router = useRouter();
  const supabase = createClientComponentClient();

  const [form, setForm] = React.useState<any>({});
  const [orgId, setOrgId] = React.useState<string | null>(null);
  const [loading, setLoading] = React.useState(false);
  const [errors, setErrors] = React.useState<string[]>([]);

  React.useEffect(() => {
    (async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return router.push("/login");
      const { data: mem } = await supabase.from("org_memberships").select("org_id").eq("user_id", user.id).maybeSingle();
      if (mem?.org_id) setOrgId(mem.org_id);
    })();
  }, []);

  const submit = async () => {
    if (!orgId) return;
    setLoading(true); setErrors([]);
    const r = await fetch("/api/validate-credentials", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ org_id: orgId, role, credentials: form }),
    });
    const j = await r.json();
    if (!r.ok) { setErrors([j?.message || "Validation failed"]); setLoading(false); return; }
    if (j.status === "verified" && (!j.errors || !j.errors.length)) {
      router.push(`/onboarding/pricing?org=${orgId}&role=${role}`);
    } else {
      router.push(`/onboarding/pricing?org=${orgId}&role=${role}&pending=1`);
    }
  };

  const set = (k: string) => (e: any) => setForm((s: any) => ({ ...s, [k]: e.target.value }));

  return (
    <div style={{ padding: 24 }}>
      <h1>Legal credentials</h1>
      {role !== "truck_stop_admin" && (
        <>
          <label>DOT (required for Owner-Op/Fleet)</label>
          <input onChange={set("dot")} placeholder="DOT #" />
          <label>MC (broker or for-hire)</label>
          <input onChange={set("mc")} placeholder="MC #" />
          <label>SCAC (optional)</label>
          <input onChange={set("scac")} placeholder="SCAC" />
          <label>Insurance COI URL</label>
          <input onChange={set("insurance_coi_url")} placeholder="https://..." />
          <label>EIN (masked/hashed)</label>
          <input onChange={set("ein")} placeholder="XX-XXXXXXX" />
          {role === "owner_operator" && (<><label>CDL last 4 (optional)</label><input onChange={set("cdl_last4")} placeholder="1234" /></>)}
          {role === "fleet_manager" && (<><label>Fleet size</label><input onChange={set("fleet_size")} type="number" min={1} /></>)}
        </>
      )}
      {role === "truck_stop_admin" && (
        <>
          <label>Legal Entity</label>
          <input onChange={set("legal_entity")} placeholder="Company LLC" />
          <label>EIN</label>
          <input onChange={set("ein")} placeholder="XX-XXXXXXX" />
          <label>Store IDs (comma-separated)</label>
          <input onChange={(e) => setForm((s: any) => ({ ...s, store_ids: e.target.value.split(",").map((x: string)=>x.trim()).filter(Boolean) }))} placeholder="1001,1002" />
        </>
      )}
      {errors.length > 0 && <div style={{ color: "tomato" }}>{errors.join("; ")}</div>}
      <button disabled={loading || !orgId} onClick={submit}>{loading ? "Checking..." : "Continue"}</button>
    </div>
  );
}
