import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

Deno.serve(async () => {
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  // Fetch ops health
  const healthResp = await fetch((Deno.env.get("FUNC_URL") || "") + "/ops/health").catch(()=>null);
  const health = healthResp && healthResp.ok ? await healthResp.json() : { sso:"unknown", scim:"unknown", state_latency_ms_p95: 9999 };

  // Factor coverage
  const { data: fcov } = await sb.from("v_ai_factor_coverage_7d").select("*");
  const minCov = (fcov||[]).reduce((m:any,r:any)=>Math.min(m, Number(r.pct_with_required ?? 100)), 100);

  const ssoOk = String(health.sso||"").toLowerCase() === "green";
  const scimOk = String(health.scim||"").toLowerCase() === "green";
  const latencyOk = Number(health.state_latency_ms_p95||9999) <= 200;
  const xaiOk = minCov >= 98;
  const status = (ssoOk && scimOk && latencyOk && xaiOk) ? "GO" : "NO-GO";

  const html = `<!doctype html><meta charset="utf-8">
  <style>
    body{font-family:system-ui;margin:2rem}
    .k{padding:.5rem;border:1px solid #eee;border-radius:.5rem;margin:.25rem 0}
    .ok{color:#166534}.bad{color:#991b1b}
  </style>
  <h1>Release ${status}</h1>
  <div class="k">State p95 latency: <span class="${latencyOk?'ok':'bad'}">${health.state_latency_ms_p95} ms</span> (SLO ≤ 200ms)</div>
  <div class="k">AI factor coverage (min 7d): <span class="${xaiOk?'ok':'bad'}">${minCov.toFixed(2)}%</span> (≥98%)</div>
  <div class="k">SSO: <span class="${ssoOk?'ok':'bad'}">${health.sso}</span> | SCIM: <span class="${scimOk?'ok':'bad'}">${health.scim}</span></div>`;
  return new Response(html, { headers: { "content-type": "text/html" }});
});
