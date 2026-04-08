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
    <main className="mx-auto max-w-4xl p-6 text-white">
      <h1 className="text-3xl font-bold">Upgrade TruckerCore</h1>
      <p className="mt-2 text-slate-300">
        Choose the premium plan that matches your role.
      </p>

      <div className="mt-6 grid gap-4 md:grid-cols-2">
        <Link
          href={`/api/stripe/checkout?plan=driver_pro&from=${encodeURIComponent(from)}`}
          className="rounded-2xl border border-slate-800 bg-slate-950 p-5"
        >
          <div className="text-lg font-semibold">Driver Pro</div>
          <div className="mt-2 text-sm text-slate-400">
            Traffic, weather, station alerts, premium route intelligence.
          </div>
        </Link>

        <Link
          href={`/api/stripe/checkout?plan=owner_operator_pro&from=${encodeURIComponent(from)}`}
          className="rounded-2xl border border-slate-800 bg-slate-950 p-5"
        >
          <div className="text-lg font-semibold">Owner Operator Pro</div>
          <div className="mt-2 text-sm text-slate-400">
            Expense analysis, profit tools, fuel/toll route optimization.
          </div>
        </Link>

        <Link
          href={`/api/stripe/checkout?plan=fleet_pro&from=${encodeURIComponent(from)}`}
          className="rounded-2xl border border-slate-800 bg-slate-950 p-5"
        >
          <div className="text-lg font-semibold">Fleet Pro</div>
          <div className="mt-2 text-sm text-slate-400">
            Advanced analytics, AI matching, dispatch intelligence.
          </div>
        </Link>

        <Link
          href={`/api/stripe/checkout?plan=broker_pro&from=${encodeURIComponent(from)}`}
          className="rounded-2xl border border-slate-800 bg-slate-950 p-5"
        >
          <div className="text-lg font-semibold">Broker Pro</div>
          <div className="mt-2 text-sm text-slate-400">
            Automation, driver matching, premium broker workflow tools.
          </div>
        </Link>
      </div>
    </main>
  );
}
