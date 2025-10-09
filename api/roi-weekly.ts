export default async function handler() {
  const baseUrl = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY as string | undefined;

  if (!baseUrl) {
    return new Response("Missing SUPABASE_URL env", { status: 500 });
  }
  if (!serviceKey) {
    return new Response("Missing SUPABASE_SERVICE_ROLE_KEY env", { status: 500 });
  }

  const projectBase = baseUrl.replace(/\/$/, "");

  // 1) Get ROI snapshot for last 30 days via Supabase Edge Function
  const roi = await fetch(`${projectBase}/functions/v1/roi_calculator`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${serviceKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ period_days: 30 }),
  }).then((r) => r.json());

  // 2) Queue an email using PostgREST
  await fetch(`${projectBase}/rest/v1/outbound_emails`, {
    method: "POST",
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      "Content-Type": "application/json",
      Prefer: "return=minimal",
    },
    body: JSON.stringify({
      to_addresses: ["exec@yourco.com"],
      subject: "Weekly ROI Snapshot",
      body_text: JSON.stringify(roi, null, 2),
      body_html: `
        <h2>Weekly ROI Snapshot</h2>
        <p>Period: ${roi.period_days} days</p>
        <ul>
          <li>Loads delivered: ${roi.loads_delivered}/${roi.loads_total}</li>
          <li>Revenue: $${roi.revenue_usd}</li>
          <li>Fuel: $${roi.fuel_usd}</li>
          <li>Estimated miles: ${roi.estimated_miles}</li>
        </ul>
        <h3>Savings</h3>
        <ul>
          <li>Fuel: $${roi.savings_breakdown?.fuel_saved_usd}</li>
          <li>Detention: $${roi.savings_breakdown?.detention_saved_usd}</li>
          <li>Revenue protection: $${roi.savings_breakdown?.revenue_protection_usd}</li>
          <li><b>Total: $${roi.savings_total_usd}</b></li>
        </ul>`,
    }),
  });

  return new Response("ok");
}
