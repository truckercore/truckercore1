import Link from 'next/link';
export default function UpgradePage() {
  return (
    <div className="min-h-screen bg-gray-950 flex items-center justify-center">
      <div className="text-center">
        <p className="text-6xl mb-4">🚀</p>
        <h1 className="text-2xl font-bold text-white mb-2">Premium Required</h1>
        <p className="text-gray-400 mb-6">Upgrade to access this feature.</p>
        <Link href="/pricing" className="bg-amber-500 text-black font-bold px-6 py-3 rounded-lg hover:opacity-90">
          View Plans →
        </Link>
      </div>
    </div>
  );
}
