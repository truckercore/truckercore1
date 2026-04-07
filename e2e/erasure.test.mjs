import assert from "node:assert/strict";
import { createClient } from "@supabase/supabase-js";

const s = createClient(process.env.URL, process.env.SERVICE_KEY);

test('gdpr erasure full-path', async () => {
  const uid = crypto.randomUUID();
  await s.from("profiles").insert({ user_id: uid, email: `test+${uid}@x.io` }).catch(()=>{});
  await s.from("route_logs").insert({ user_id: uid, ts: new Date().toISOString() }).catch(()=>{});

  const res = await fetch(process.env.ERASURE_FN, {
    method:"POST",
    headers: { "content-type":"application/json" },
    body: JSON.stringify({ userId: uid })
  });
  assert.equal(res.ok, true);

  const tables = [
    { name: "profiles", col: "user_id" },
    { name: "route_logs", col: "user_id" },
    { name: "invoices", col: "org_id" },
    { name: "forum_posts", col: "author_id" }
  ];
  for (const t of tables) {
    const { count, error } = await s.from(t.name).select('*', { head: true, count: 'exact' }).eq(t.col, uid);
    assert.ifError(error);
    assert.equal(Number(count || 0), 0, `Residual in ${t.name}`);
  }
});
