import React from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Truck, FileText, BarChart3, Settings } from 'lucide-react';

export default function Navigation() {
  const pathname = usePathname();

  const navItems = [
    {
      name: 'Fleet Manager',
      href: '/fleet/dashboard',
      icon: Truck,
      active: pathname?.startsWith('/fleet') ?? false,
    },
    {
      name: 'Freight Broker',
      href: '/freight-broker-dashboard',
      icon: FileText,
      active: pathname?.startsWith('/freight') || pathname === '/freight-broker-dashboard',
    },
    {
      name: 'Analytics',
      href: '/analytics',
      icon: BarChart3,
      active: pathname === '/analytics',
    },
    {
      name: 'Settings',
      href: '/settings',
      icon: Settings,
      active: pathname === '/settings',
    },
  ];

  return (
    <nav className="bg-white border-b">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center h-16">
          <div className="flex items-center gap-8">
            <Link href="/" className="text-xl font-bold text-gray-900">
              TMS Platform
            </Link>
            <div className="flex gap-1">
              {navItems.map((item) => {
                const Icon = item.icon;
                return (
                  <Link
                    key={item.name}
                    href={item.href}
                    className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                      item.active
                        ? 'bg-blue-50 text-blue-700'
                        : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900'
                    }`}
                  >
                    <Icon className="w-4 h-4" />
                    {item.name}
                  </Link>
                );
              })}
            </div>
          </div>
        </div>
      </div>
    </nav>
  );
}
