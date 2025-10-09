import { getLaneRates, getBrokerCredit } from '@/lib/data/pricing.service'

export const dynamic = 'force-dynamic'

export default async function DataCheckPage() {
  const rates = await getLaneRates({ origin: 'Dallas', destination: 'Atlanta' })
  const credit = await getBrokerCredit('demo-broker')

  return (
    <main className="space-y-4">
      <section className="rounded border bg-white p-4">
        <h2 className="font-semibold mb-2">Lane Rates (Dallas → Atlanta)</h2>
        {rates.error ? (
          <div className="text-red-600 text-sm">Error: {rates.error.message} · requestId={rates.error.requestId}</div>
        ) : rates.data ? (
          <div className="text-sm">p50: {rates.data.p50 ?? '—'} · p80: {rates.data.p80 ?? '—'}</div>
        ) : (
          <div className="text-sm text-gray-600">No rate data</div>
        )}
      </section>

      <section className="rounded border bg-white p-4">
        <h2 className="font-semibold mb-2">Broker Credit (demo-broker)</h2>
        {credit.error ? (
          <div className="text-red-600 text-sm">Error: {credit.error.message} · requestId={credit.error.requestId}</div>
        ) : credit.data ? (
          <div className="text-sm">tier: {credit.data.tier ?? '—'} · d2p: {credit.data.d2p_days ?? '—'} · updated: {credit.data.updated_at ? new Date(credit.data.updated_at).toLocaleDateString() : '—'}</div>
        ) : (
          <div className="text-sm text-gray-600">No credit info</div>
        )}
      </section>
    </main>
  )
}
