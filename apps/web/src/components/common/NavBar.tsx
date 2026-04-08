'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

const baseLinkClass =
  'rounded-lg px-3 py-2 text-sm font-medium transition hover:bg-slate-800 hover:text-white';
const activeLinkClass = 'bg-slate-800 text-white';
const inactiveLinkClass = 'text-slate-300';

function navClass(pathname: string, href: string) {
  const active =
    pathname === href || (href !== '/' && pathname.startsWith(`${href}/`));
  return `${baseLinkClass} ${active ? activeLinkClass : inactiveLinkClass}`;
}

export default function NavBar() {
  const pathname = usePathname();

  return (
    <nav className="border-b border-slate-800 bg-slate-950 text-white">
      <div className="mx-auto flex max-w-7xl items-center justify-between px-4 py-3">
        <Link href="/" className="text-lg font-bold tracking-wide">
          TruckerCore
        </Link>

        <div className="flex items-center gap-2">
          <Link href="/gps" className={navClass(pathname, '/gps')}>
            GPS
          </Link>

          <Link href="/route-planning" className={navClass(pathname, '/route-planning')}>
            Route Planning
          </Link>

          <Link href="/driver-dashboard" className={navClass(pathname, '/driver-dashboard')}>
            Driver
          </Link>

          <Link
            href="/owner-operator-dashboard"
            className={navClass(pathname, '/owner-operator-dashboard')}
          >
            Owner Operator
          </Link>

          <Link
            href="/fleet-manager-dashboard"
            className={navClass(pathname, '/fleet-manager-dashboard')}
          >
            Fleet
          </Link>

          <Link
            href="/freight-broker-dashboard"
            className={navClass(pathname, '/freight-broker-dashboard')}
          >
            Broker
          </Link>
        </div>
      </div>
    </nav>
  );
}