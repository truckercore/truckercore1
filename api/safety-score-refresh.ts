export default async function handler() {
  const baseUrl = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY as string | undefined;

  if (!baseUrl) {
    return new Response("Missing SUPABASE_URL env", { status: 500 });
  }
  if (!serviceKey) {
    return new Response("Missing SUPABASE_SERVICE_ROLE_KEY env", { status: 500 });
  }

  // Call RPC directly via REST to refresh scores
  const rpcUrl = `${baseUrl.replace(/\/$/, "")}/rest/v1/rpc/refresh_safety_scores`;
  await fetch(rpcUrl, {
    method: "POST",
    headers: {
      "apikey": serviceKey,
      "Authorization": `Bearer ${serviceKey}`,
      "Content-Type": "application/json"
    },
    body: "{}"
  });
  return new Response("ok");
}
