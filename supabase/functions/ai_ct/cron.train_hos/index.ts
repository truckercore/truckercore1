// functions/ai_ct/cron.train_hos/index.ts
Deno.serve(async () => {
  const webhook = Deno.env.get("TRAINER_WEBHOOK_HOS");
  if (!webhook) return new Response(JSON.stringify({ error: "missing TRAINER_WEBHOOK_HOS" }), { status: 500, headers:{"content-type":"application/json"} });
  const r = await fetch(webhook, { method:"POST" });
  if (!r.ok) return new Response(JSON.stringify({error: await r.text()}),{status:500, headers:{"content-type":"application/json"}});
  const reg = await r.json();
  const funcUrl = Deno.env.get("FUNC_URL");
  if (funcUrl) {
    await fetch(`${funcUrl}/ai/register_model`, {
      method:"POST", headers:{ "content-type":"application/json" }, body: JSON.stringify(reg)
    });
  }
  return new Response(JSON.stringify({ ok:true, model: reg }), { headers:{ "content-type":"application/json"}});
});
