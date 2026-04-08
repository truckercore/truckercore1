import Link from 'next/link';

type UpgradePageProps = {
  searchParams: Promise<{
    from?: string;
  }>;
};

export default async function UpgradePage({ searchParams }: UpgradePageProps) {
  const params = await searchParams;
  const from = params.from ?? '/';

  return (
    <main className="mx-auto max-w-2xl p-6 text-white">
      <h1 className="text-3xl font-bold">Upgrade to Premium</h1>
      <p className="mt-3 text-gray-300">
        Unlock advanced GPS, analytics, AI tools, and premium dashboards.
      </p>

      <div className="mt-6 rounded-2xl border border-slate-800 bg-slate-900 p-6">
        <p className="text-sm text-gray-400">Return path after upgrade</p>
        <p className="mt-1 break-all text-sm text-white">{from}</p>

        <div className="mt-6 flex gap-3">
          <Link
            href="/api/stripe/checkout?plan=fleet_pro"
            className="rounded-lg bg-amber-500 px-4 py-2 font-medium text-black"
          >
            Upgrade Now
          </Link>

          <Link
            href={from}
            className="rounded-lg border border-slate-700 px-4 py-2 font-medium text-white"
          >
            Back
          </Link>
        </div>
      </div>
    </main>
  );
}
