// apps/web/lib/paywallClient.ts
export async function startUpgrade(args: { user_id: string; org_id: string; tier: "basic"|"standard"|"premium"|"enterprise" }) {
  const { user_id, org_id, tier } = args;

  const nres = await fetch("/api/paywall/nonce", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ user_id, org_id }),
  });
  if (!nres.ok) throw new Error("nonce_failed");
  const { nonce } = await nres.json();

  const cres = await fetch("/api/billing/checkout", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ user_id, org_id, tier, nonce }),
  });
  const { url } = await cres.json();
  if (!url) throw new Error("failed_to_create_session");
  window.location.href = url as string;
}
