"use client";

import React from 'react';
import { useRouter } from 'next/navigation';
import { Briefcase, Truck, Users } from 'lucide-react';

interface DashboardOption {
  id: string;
  title: string;
  description: string;
  icon: React.ReactNode;
  route: string;
  color: string;
}

export const DashboardSelector: React.FC = () => {
  const router = useRouter();

  const dashboards: DashboardOption[] = [
    {
      id: 'freight-broker',
      title: 'Freight Broker',
      description: 'Manage loads, carriers, and customer relationships',
      icon: <Briefcase size={48} />,
      route: '/freight-broker-dashboard',
      color: 'from-blue-600 to-blue-800',
    },
    {
      id: 'owner-operator',
      title: 'Owner Operator',
      description: 'Find loads, track earnings, and manage your truck',
      icon: <Truck size={48} />,
      route: '/owner-operator-dashboard',
      color: 'from-green-600 to-green-800',
    },
    {
      id: 'fleet-manager',
      title: 'Fleet Manager',
      description: 'Oversee fleet operations, maintenance, and compliance',
      icon: <Users size={48} />,
      route: '/fleet-manager-dashboard',
      color: 'from-purple-600 to-purple-800',
    },
  ];

  const handleSelect = (route: string) => {
    router.push(route);
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        {/* Header */}
        <div className="text-center mb-12">
          <h1 className="text-5xl font-bold text-white mb-4">Freight Management System</h1>
          <p className="text-xl text-gray-300">Select your dashboard to get started</p>
        </div>

        {/* Dashboard Cards */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-8 mb-12">
          {dashboards.map((dashboard) => (
            <button
              key={dashboard.id}
              onClick={() => handleSelect(dashboard.route)}
              className="bg-white rounded-2xl shadow-2xl p-8 hover:scale-105 transform transition-all duration-300 cursor-pointer group"
            >
              <div
                className={`w-20 h-20 rounded-full bg-gradient-to-r ${dashboard.color} flex items-center justify-center text-white mb-6 mx-auto group-hover:rotate-12 transition-transform duration-300`}
              >
                {dashboard.icon}
              </div>
              <h2 className="text-2xl font-bold text-gray-900 mb-3">{dashboard.title}</h2>
              <p className="text-gray-600 mb-6">{dashboard.description}</p>
              <div className="text-blue-600 font-semibold flex items-center justify-center gap-2 group-hover:gap-4 transition-all">
                Open Dashboard
                <span className="text-2xl">→</span>
              </div>
            </button>
          ))}
        </div>

        {/* Features Grid */}
        <div className="bg-white rounded-2xl shadow-2xl p-8">
          <h3 className="text-2xl font-bold text-gray-900 mb-6 text-center">Platform Features</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            <div className="text-center">
              <div className="text-4xl mb-2">📊</div>
              <h4 className="font-semibold text-gray-900 mb-1">Real-time Analytics</h4>
              <p className="text-sm text-gray-600">Track revenue, margins, and performance</p>
            </div>
            <div className="text-center">
              <div className="text-4xl mb-2">🤖</div>
              <h4 className="font-semibold text-gray-900 mb-1">Smart Matching</h4>
              <p className="text-sm text-gray-600">AI-powered carrier and load matching</p>
            </div>
            <div className="text-center">
              <div className="text-4xl mb-2">📄</div>
              <h4 className="font-semibold text-gray-900 mb-1">Document Generation</h4>
              <p className="text-sm text-gray-600">One-click BOL, RC, and invoice creation</p>
            </div>
            <div className="text-center">
              <div className="text-4xl mb-2">✅</div>
              <h4 className="font-semibold text-gray-900 mb-1">Compliance Tracking</h4>
              <p className="text-sm text-gray-600">MC# verification and insurance monitoring</p>
            </div>
          </div>
        </div>

        {/* Quick Stats */}
        <div className="mt-12 grid grid-cols-1 md:grid-cols-4 gap-6">
          <div className="bg-gradient-to-r from-blue-600 to-blue-800 rounded-xl p-6 text-white text-center">
            <div className="text-4xl font-bold mb-2">1M+</div>
            <div className="text-blue-100">Loads Managed</div>
          </div>
          <div className="bg-gradient-to-r from-green-600 to-green-800 rounded-xl p-6 text-white text-center">
            <div className="text-4xl font-bold mb-2">10K+</div>
            <div className="text-green-100">Active Carriers</div>
          </div>
          <div className="bg-gradient-to-r from-purple-600 to-purple-800 rounded-xl p-6 text-white text-center">
            <div className="text-4xl font-bold mb-2">99.8%</div>
            <div className="text-purple-100">Uptime</div>
          </div>
          <div className="bg-gradient-to-r from-yellow-600 to-yellow-800 rounded-xl p-6 text-white text-center">
            <div className="text-4xl font-bold mb-2">24/7</div>
            <div className="text-yellow-100">Support</div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default DashboardSelector;
