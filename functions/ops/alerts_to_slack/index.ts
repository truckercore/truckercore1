Deno.serve(async (req) => {
  const body = await req.json().catch(()=> ({}));
  const url = Deno.env.get("SLACK_WEBHOOK_URL");
  if (!url) return new Response(JSON.stringify({ error: "missing SLACK_WEBHOOK_URL" }), { status: 500, headers: { "content-type":"application/json" }});
  await fetch(url, {
    method:"POST",
    headers:{ "content-type":"application/json" },
    body: JSON.stringify({ text: `AI Alert: ${JSON.stringify(body)}` })
  });
  return new Response("ok");
});