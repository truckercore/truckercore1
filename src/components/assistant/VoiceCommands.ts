export type VoiceIntent =
  | { type: "nearby_loads"; lat:number; lng:number; radius:number }
  | { type: "ifta_quarter"; quarter: string; orgId: string };

export async function runVoiceIntent(intent: VoiceIntent) {
  switch (intent.type) {
    case "nearby_loads":
      return fetch("/api/optimizer/deadhead", { method:"POST", headers:{"Content-Type":"application/json"}, body: JSON.stringify({ current:{ lat:intent.lat, lng:intent.lng }, radiusMiles:intent.radius }) }).then(r=>r.json());
    case "ifta_quarter":
      return fetch(`${process.env.NEXT_PUBLIC_FUNCTIONS_URL}/generate-ifta-report?quarter=${encodeURIComponent(intent.quarter)}&org_id=${encodeURIComponent(intent.orgId)}`, { headers: { Authorization: `Bearer ${localStorage.getItem("supabase_jwt")}` } });
  }
}
