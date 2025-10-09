import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import Head from "next/head";

// TODO: replace with your actual orgId loader (e.g., from session/user profile)
const useOrgId = () => {
  // For now, read from ?orgId=... or fallback to localStorage/dev
  const [orgId, setOrgId] = useState<string | null>(null);
  useEffect(() => {
    const urlOrg = new URLSearchParams(window.location.search).get("orgId");
    if (urlOrg) setOrgId(urlOrg);
    else setOrgId(localStorage.getItem("dev_org_id"));
  }, []);
  return orgId;
};

type Row = { provider: string; connected: boolean; external_account_id: string | null };

export default function AdminIntegrations() {
  const orgId = useOrgId();
  const [rows, setRows] = useState<Row[] | null>(null);
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const readiness = useMemo(
    () => ({
      samsara: Boolean(process.env.NEXT_PUBLIC_SAMSARA_READY),
      qbo: Boolean(process.env.NEXT_PUBLIC_QBO_READY),
    }),
    []
  );

  async function refresh() {
    if (!orgId) return;
    setLoading(true);
    setErr(null);
    try {
      const res = await fetch(`/api/admin/integrations/status?orgId=${orgId}`);
      if (!res.ok) throw new Error(await res.text());
      const data = await res.json();
      setRows(data.rows);
    } catch (e: any) {
      setErr(e.message ?? String(e));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    refresh();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [orgId]);

  return (
    <>
      <Head>
        <title>Integrations • Admin</title>
      </Head>
      <main className="mx-auto max-w-3xl p-6">
        <h1 className="text-2xl font-bold">Integrations</h1>
        {!orgId && (
          <div className="mt-3 rounded bg-yellow-100 p-3 text-sm">
            No <code>orgId</code> detected. Append <code>?orgId=&lt;uuid&gt;</code> to the URL or set
            <code> localStorage.dev_org_id</code> for local testing.
          </div>
        )}

        <div className="mt-4 flex items-center gap-3">
          <button onClick={refresh} className="rounded bg-gray-800 px-3 py-2 text-white disabled:opacity-50" disabled={loading}>
            Refresh
          </button>
          {loading && <span className="text-sm text-gray-500">Loading…</span>}
          {err && <span className="text-sm text-red-600">Error: {err}</span>}
        </div>

        <div className="mt-6 overflow-hidden rounded-lg border">
          <table className="min-w-full text-left text-sm">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-4 py-3">Provider</th>
                <th className="px-4 py-3">Status</th>
                <th className="px-4 py-3">External Account</th>
                <th className="px-4 py-3"></th>
              </tr>
            </thead>
            <tbody>
              {(rows ?? []).map((r) => {
                const ready = (r.provider === "samsara" && readiness.samsara) || (r.provider === "qbo" && readiness.qbo);
                return (
                  <tr key={r.provider} className="border-t">
                    <td className="px-4 py-3 font-medium uppercase">{r.provider}</td>
                    <td className="px-4 py-3">
                      {r.connected ? (
                        <span className="rounded bg-green-100 px-2 py-1 text-green-700">Connected</span>
                      ) : (
                        <span className="rounded bg-gray-100 px-2 py-1 text-gray-700">Not connected</span>
                      )}
                    </td>
                    <td className="px-4 py-3">{r.external_account_id ?? "—"}</td>
                    <td className="px-4 py-3">
                      {r.connected ? (
                        <form
                          onSubmit={async (e) => {
                            e.preventDefault();
                            if (!orgId) return;
                            const res = await fetch(`/api/disconnect/${r.provider}?orgId=${orgId}`);
                            if (!res.ok) alert(await res.text());
                            else refresh();
                          }}
                        >
                          <button className="rounded bg-red-600 px-3 py-2 text-white">Disconnect</button>
                        </form>
                      ) : (
                        <Link
                          href={`/api/connect/${r.provider}?orgId=${orgId}`}
                          className={`rounded px-3 py-2 ${ready ? "bg-blue-600 text-white" : "bg-gray-300 text-gray-600 cursor-not-allowed"}`}
                          aria-disabled={!ready}
                          onClick={(e) => {
                            if (!ready) e.preventDefault();
                          }}
                          title={ready ? `Connect ${r.provider}` : "Awaiting provider keys"}
                        >
                          Connect
                        </Link>
                      )}
                    </td>
                  </tr>
                );
              })}
              {rows?.length === 0 && (
                <tr>
                  <td className="px-4 py-6 text-gray-500" colSpan={4}>
                    No providers found.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </main>
    </>
  );
}
