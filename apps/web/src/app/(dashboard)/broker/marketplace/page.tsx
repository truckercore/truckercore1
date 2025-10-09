import { OpenLoadsList } from '@/features/broker/marketplace/OpenLoadsList'

export default function BrokerMarketplacePage() {
  return (
    <div className="p-4 space-y-4">
      <h1 className="text-xl font-semibold">Broker Marketplace</h1>
      <OpenLoadsList />
    </div>
  )
}
