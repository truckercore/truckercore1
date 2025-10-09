import { Suspense, useState } from 'react'
import { ExpensesTab } from '@/features/ownerop/ExpensesTab'
import { ProfitabilityTab } from '@/features/ownerop/ProfitabilityTab'

export default function OwnerOperatorPage() {
  return (
    <div className="p-4 space-y-4">
      <h1 className="text-xl font-semibold">Owner-Operator</h1>
      <Tabs />
    </div>
  )
}

function Tabs() {
  const [tab, setTab] = useState<'expenses'|'profit'>('expenses') as any
  return (
    <div className="space-y-3">
      <div className="flex gap-2">
        <button className={`px-3 py-1 rounded border ${tab==='expenses'?'bg-blue-600 text-white':''}`} onClick={()=>setTab('expenses')}>My Expenses</button>
        <button className={`px-3 py-1 rounded border ${tab==='profit'?'bg-blue-600 text-white':''}`} onClick={()=>setTab('profit')}>Profitability</button>
      </div>
      <div>
        <Suspense fallback={<div className='p-4'>Loading…</div>}>
          {tab === 'expenses' ? <ExpensesTab /> : <ProfitabilityTab />}
        </Suspense>
      </div>
    </div>
  )
}
