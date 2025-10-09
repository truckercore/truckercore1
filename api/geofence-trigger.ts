export default async function handler(req: Request) {
  const baseUrl = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!baseUrl) {
    return new Response("Missing SUPABASE_URL env", { status: 500 });
  }
  if (!serviceKey) {
    return new Response("Missing SUPABASE_SERVICE_ROLE_KEY env", { status: 500 });
  }

  const fnUrl = `${baseUrl.replace(/\/$/, "")}/functions/v1/geofence_engine`;

  await fetch(fnUrl, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${serviceKey}`,
      "Content-Type": "application/json"
    },
    // body not required for this function
  });

  return new Response("ok");
}
