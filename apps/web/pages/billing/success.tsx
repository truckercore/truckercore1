// apps/web/pages/billing/success.tsx
import { useRouter } from "next/router";
import { useEffect, useState } from "react";

export default function Success() {
  const router = useRouter();
  const [msg, setMsg] = useState("Verifying…");

  useEffect(() => {
    const session_id = router.query.session_id as string | undefined;
    const nonce = router.query.nonce as string | undefined;

    // TODO: Replace with your real session context
    const user_id = (window as any).__USER_ID__;
    const org_id = (window as any).__ORG_ID__;

    if (session_id && nonce && user_id && org_id) {
      fetch("/api/paywall/verify", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ session_id, nonce, user_id, org_id }),
      }).then(async (r) => {
        if (r.ok) {
          setMsg("Upgraded!");
          setTimeout(() => (window.location.href = "/"), 600);
        } else {
          const e = await r.json().catch(() => ({}));
          setMsg(`Verify failed: ${e.error || r.status}`);
        }
      });
    }
  }, [router.query]);

  return <div style={{ padding: 24 }}>{msg}</div>;
}
