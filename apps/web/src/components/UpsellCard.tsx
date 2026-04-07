import React, { useState } from "react";
import type { UpsellCardProps } from "./UpsellCard.types";

export function UpsellCard({ orgId, item, entLoaded, disabled, token, onCheckoutUrl, onAfterSuccess, logEvt }: UpsellCardProps) {
  const [busy, setBusy] = useState(false);

  const handleUpgrade = async () => {
    if (busy) return;
    setBusy(true);
    const requestId = (globalThis.crypto?.randomUUID?.() ?? `${Date.now().toString(36)}${Math.random().toString(36).slice(2,10)}`);
    logEvt({ t: "upsell_click", feature: item.key, tier: item.tier, org_id: orgId, requestId, variant: item.variant });
    try {
      const r = await fetch("/functions/v1/create_checkout", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-Request-Id": requestId, Authorization: `Bearer ${token}` },
        body: JSON.stringify({ priceId: item.price_id, orgId }),
      });
      const j = await r.json();
      if (j.status !== "ok" || !j.url) throw new Error(j.message ?? "checkout failed");
      logEvt({ t: "checkout_open", priceId: item.price_id, requestId, variant: item.variant });
      if (onCheckoutUrl) onCheckoutUrl(j.url);
      else window.location.href = j.url as string;
      if (onAfterSuccess) onAfterSuccess();
    } catch (e: any) {
      logEvt({ t: "checkout_error", priceId: item.price_id, requestId, message: String(e?.message ?? e), variant: item.variant });
    } finally {
      setBusy(false);
    }
  };

  const isDisabled = disabled || !entLoaded || busy;

  return (
    <div role="region" aria-label={`Upsell ${item.headline}`} className="upsell-card">
      <h3>{item.headline}</h3>
      {item.blurb && <p>{item.blurb}</p>}
      <div className="actions">
        <button
          aria-label={`Upgrade to ${item.tier}`}
          disabled={isDisabled}
          onClick={handleUpgrade}
        >
          {busy ? "Processing…" : "Upgrade"}
        </button>
        {item.runbook_url && (
          <a href={item.runbook_url} target="_blank" rel="noreferrer">
            Learn more
          </a>
        )}
      </div>
    </div>
  );
}

export default UpsellCard;
