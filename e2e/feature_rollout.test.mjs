import assert from "node:assert/strict";
import { createClient } from "@supabase/supabase-js";

const s = createClient(process.env.URL, process.env.SERVICE_KEY);
const FK = "ai.prescriptive";
const ORG_A = process.env.ORG_A;
const ORG_B = process.env.ORG_B;

if (!ORG_A || !ORG_B) {
  console.log('[skip] feature_rollout: missing ORG_A/ORG_B');
  process.exit(0);
}

test('kill-switch and canary', async () => {
  await s.from("feature_rollouts").upsert({ feature_key: FK, disabled_globally: true });
  let { data: r1 } = await s.rpc("resolve_entitlements_and_settings", { p_org_id: ORG_A, p_user_id: ORG_A, p_role: 'driver' });
  assert.equal(r1.features[FK], false);

  await s.from("feature_rollouts").upsert({ feature_key: FK, disabled_globally: false, canary_orgs: [ORG_A] });

  let { data: r2 } = await s.rpc("resolve_entitlements_and_settings", { p_org_id: ORG_B, p_user_id: ORG_B, p_role: 'driver' });
  assert.equal(r2.features[FK], false);

  let { data: r3 } = await s.rpc("resolve_entitlements_and_settings", { p_org_id: ORG_A, p_user_id: ORG_A, p_role: 'driver' });
  assert.equal(r3.features[FK], true);
});
