"use client";

import React from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Truck, Users, Briefcase, Home } from 'lucide-react';

export const DashboardNavigation: React.FC = () => {
  const pathname = usePathname();

  const isActive = (path: string) => pathname === path;

  const baseLinkClasses =
    'flex items-center gap-2 px-4 py-2 rounded-lg transition-all';

  return (
    <div className="bg-gray-900 text-white shadow-lg">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          <div className="flex items-center">
            <Link href="/" className="text-xl font-bold hover:text-gray-300 transition">
              🚛 Freight Management
            </Link>
          </div>
          <nav className="flex gap-1">
            <Link
              href="/"
              className={`${baseLinkClasses} ${
                isActive('/') ? 'bg-white text-gray-900 font-semibold' : 'hover:bg-gray-800 text-gray-300'
              }`}
            >
              <Home size={18} />
              <span className="hidden md:inline">Home</span>
            </Link>
            <Link
              href="/freight-broker-dashboard"
              className={`${baseLinkClasses} ${
                isActive('/freight-broker-dashboard')
                  ? 'bg-white text-gray-900 font-semibold'
                  : 'hover:bg-gray-800 text-gray-300'
              }`}
            >
              <Briefcase size={18} />
              <span className="hidden md:inline">Freight Broker</span>
            </Link>
            <Link
              href="/owner-operator-dashboard"
              className={`${baseLinkClasses} ${
                isActive('/owner-operator-dashboard')
                  ? 'bg-white text-gray-900 font-semibold'
                  : 'hover:bg-gray-800 text-gray-300'
              }`}
            >
              <Truck size={18} />
              <span className="hidden md:inline">Owner Operator</span>
            </Link>
            <Link
              href="/fleet-manager-dashboard"
              className={`${baseLinkClasses} ${
                isActive('/fleet-manager-dashboard')
                  ? 'bg-white text-gray-900 font-semibold'
                  : 'hover:bg-gray-800 text-gray-300'
              }`}
            >
              <Users size={18} />
              <span className="hidden md:inline">Fleet Manager</span>
            </Link>
          </nav>
        </div>
      </div>
    </div>
  );
};

export default DashboardNavigation;
