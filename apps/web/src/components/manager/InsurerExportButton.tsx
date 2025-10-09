// TypeScript
export function InsurerExportButton({ orgId }: { orgId: string }) {
  const month = new Date().toISOString().slice(0, 7);
  const onClick = () => {
    const url = `${process.env.NEXT_PUBLIC_SUPABASE_EDGE_URL}/insurer-export?org_id=${orgId}&month=${month}`;
    try {
      window.open(url, "_blank");
    } catch {
      window.location.href = url;
    }
  };
  return (
    <button onClick={onClick} className="px-4 py-2 rounded-xl bg-indigo-600 text-white">
      Insurer Export (PDF+CSV)
    </button>
  );
}
