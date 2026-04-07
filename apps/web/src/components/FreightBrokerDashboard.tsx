import React, { useState, useEffect } from 'react';
import { Truck, FileText, DollarSign, TrendingUp, Package, Users } from 'lucide-react';
import { LoadCreationDialog } from './LoadCreationDialog';
import { CarrierOnboardingDialog } from './CarrierOnboardingDialog';
import { DocumentGenerationService } from '../services/documentGenerationService';
import { Load, Carrier, Invoice, LoadAnalytics } from '../types/freight';
import { RateCalculator } from '../utils/rateCalculator';
import { CarrierVerificationService } from '../services/carrierVerificationService';
import { DashboardNavigation } from './DashboardNavigation';

const FreightBrokerDashboard: React.FC<{ title?: string }> = ({ title }) => {
  const [loads, setLoads] = useState<Load[]>([]);
  const [carriers, setCarriers] = useState<Carrier[]>([]);
  const [invoices, setInvoices] = useState<Invoice[]>([]);
  const [analytics, setAnalytics] = useState<LoadAnalytics | null>(null);
  const [showLoadDialog, setShowLoadDialog] = useState(false);
  const [showCarrierDialog, setShowCarrierDialog] = useState(false);
  const [activeTab, setActiveTab] = useState<'loads' | 'carriers' | 'documents' | 'analytics'>(
    'loads'
  );

  // Load mock data
  useEffect(() => {
    loadMockData();
  }, []);

  // Calculate analytics whenever loads change
  useEffect(() => {
    calculateAnalytics();
  }, [loads]);

  const loadMockData = () => {
    // Mock carriers
    const mockCarriers: Carrier[] = [
      {
        id: 'CARR-1',
        companyName: 'Swift Transportation',
        mcNumber: '123456',
        dotNumber: '7891011',
        contactName: 'John Smith',
        email: 'john@swift.com',
        phone: '5551234567',
        status: 'approved',
        rating: 4.8,
        totalLoads: 150,
        onTimeDeliveryRate: 96,
        insuranceVerified: true,
        insuranceExpiry: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString(),
        authorityStatus: 'active',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
      {
        id: 'CARR-2',
        companyName: 'Prime Inc',
        mcNumber: '234567',
        dotNumber: '8901112',
        contactName: 'Sarah Johnson',
        email: 'sarah@primeinc.com',
        phone: '5552345678',
        status: 'approved',
        rating: 4.6,
        totalLoads: 120,
        onTimeDeliveryRate: 94,
        insuranceVerified: true,
        insuranceExpiry: new Date(Date.now() + 300 * 24 * 60 * 60 * 1000).toISOString(),
        authorityStatus: 'active',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
    ];
    setCarriers(mockCarriers);

    // Mock loads
    const mockLoads: Load[] = [
      {
        id: 'LOAD-1',
        customerId: 'CUST-1',
        customerName: 'Walmart Distribution',
        carrierId: 'CARR-1',
        carrierName: 'Swift Transportation',
        status: 'in_transit',
        pickupLocation: {
          address: '123 Industrial Blvd',
          city: 'Dallas',
          state: 'TX',
          zipCode: '75201',
        },
        deliveryLocation: {
          address: '456 Commerce St',
          city: 'Phoenix',
          state: 'AZ',
          zipCode: '85001',
        },
        pickupDate: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
        deliveryDate: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString(),
        equipmentType: 'dry_van',
        weight: 42000,
        distance: 1050,
        commodity: 'Consumer Electronics',
        customerRate: 3500,
        carrierRate: 2800,
        margin: 700,
        marginPercentage: 20,
        documents: [],
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
      {
        id: 'LOAD-2',
        customerId: 'CUST-2',
        customerName: 'Target Logistics',
        carrierId: 'CARR-2',
        carrierName: 'Prime Inc',
        status: 'delivered',
        pickupLocation: {
          address: '789 Warehouse Way',
          city: 'Chicago',
          state: 'IL',
          zipCode: '60601',
        },
        deliveryLocation: {
          address: '321 Distribution Dr',
          city: 'Atlanta',
          state: 'GA',
          zipCode: '30301',
        },
        pickupDate: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000).toISOString(),
        deliveryDate: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString(),
        equipmentType: 'reefer',
        weight: 38000,
        distance: 750,
        commodity: 'Frozen Foods',
        customerRate: 2800,
        carrierRate: 2300,
        margin: 500,
        marginPercentage: 17.86,
        documents: [],
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
    ];
    setLoads(mockLoads);
  };

  const calculateAnalytics = () => {
    const totalRevenue = loads.reduce((sum, load) => sum + load.customerRate, 0);
    const totalCost = loads.reduce((sum, load) => sum + (load.carrierRate || 0), 0);
    const totalMargin = totalRevenue - totalCost;
    const averageMarginPercentage = totalRevenue > 0 ? (totalMargin / totalRevenue) * 100 : 0;

    const loadsByStatus = loads.reduce((acc, load) => {
      (acc as any)[load.status] = ((acc as any)[load.status] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);

    const revenueByCustomer = Object.values(
      loads.reduce((acc: any, load) => {
        if (!acc[load.customerId]) {
          acc[load.customerId] = {
            customerId: load.customerId,
            customerName: load.customerName,
            revenue: 0,
          };
        }
        acc[load.customerId].revenue += load.customerRate;
        return acc;
      }, {} as Record<string, any>)
    );

    const marginByLoad = loads
      .filter((load) => load.margin)
      .map((load) => ({
        loadId: load.id,
        margin: load.margin!,
        marginPercentage: load.marginPercentage!,
      }))
      .sort((a, b) => b.margin - a.margin);

    setAnalytics({
      totalRevenue,
      totalCost,
      totalMargin,
      averageMarginPercentage,
      loadsByStatus,
      revenueByCustomer,
      marginByLoad,
    });
  };

  const handleCreateLoad = async (load: Partial<Load>) => {
    setLoads((prev) => [...prev, load as Load]);
  };

  const handleAddCarrier = async (carrier: Partial<Carrier>) => {
    setCarriers((prev) => [...prev, carrier as Carrier]);
  };

  const handleGenerateDocument = (type: 'rate_confirmation' | 'bol' | 'invoice', load: Load) => {
    let blob: Blob;
    let filename: string;

    const brokerInfo = {
      name: 'ABC Freight Brokers',
      mcNumber: '999888',
      phone: '555-000-0000',
    };

    switch (type) {
      case 'rate_confirmation':
        blob = DocumentGenerationService.generateRateConfirmation(load, brokerInfo);
        filename = `rate_confirmation_${load.id}.pdf`;
        break;
      case 'bol':
        blob = DocumentGenerationService.generateBOL(load);
        filename = `bol_${load.id}.pdf`;
        break;
      case 'invoice':
        blob = DocumentGenerationService.generateInvoice(load, `INV-${Date.now()}`);
        filename = `invoice_${load.id}.pdf`;
        break;
    }

    // Download the document
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  };

  const handleRateCarrier = (carrierId: string, rating: number) => {
    setCarriers((prev) =>
      prev.map((carrier) =>
        carrier.id === carrierId
          ? {
              ...carrier,
              rating: (carrier.rating * carrier.totalLoads + rating) / (carrier.totalLoads + 1),
            }
          : carrier
      )
    );
  };

  const getStatusColor = (status: string) => {
    const colors: Record<string, string> = {
      posted: 'bg-yellow-100 text-yellow-800',
      assigned: 'bg-blue-100 text-blue-800',
      in_transit: 'bg-purple-100 text-purple-800',
      delivered: 'bg-green-100 text-green-800',
      cancelled: 'bg-red-100 text-red-800',
    };
    return colors[status] || 'bg-gray-100 text-gray-800';
  };

  const getCarrierStatusColor = (status: string) => {
    const colors: Record<string, string> = {
      approved: 'bg-green-100 text-green-800',
      pending: 'bg-yellow-100 text-yellow-800',
      rejected: 'bg-red-100 text-red-800',
      suspended: 'bg-gray-100 text-gray-800',
    };
    return colors[status] || 'bg-gray-100 text-gray-800';
  };

  return (
    <>
      <DashboardNavigation />
      <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <div className="bg-white shadow">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div className="flex justify-between items-center">
            <div>
              <h1 className="text-3xl font-bold text-gray-900">{title || 'Freight Broker Dashboard'}</h1>
              <p className="text-gray-600 mt-1">Manage loads, carriers, and documents</p>
            </div>
            <div className="flex gap-3">
              <button
                onClick={() => setShowCarrierDialog(true)}
                className="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 font-semibold flex items-center gap-2"
              >
                <Users size={20} />
                Add Carrier
              </button>
              <button
                onClick={() => setShowLoadDialog(true)}
                className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 font-semibold flex items-center gap-2"
              >
                <Package size={20} />
                Post Load
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Stats Overview */}
      {analytics && (
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
            <div className="bg-white rounded-lg shadow p-6">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-gray-600">Total Revenue</p>
                  <p className="text-2xl font-bold text-gray-900">
                    ${analytics.totalRevenue.toLocaleString()}
                  </p>
                </div>
                <div className="bg-green-100 p-3 rounded-full">
                  <DollarSign className="text-green-600" size={24} />
                </div>
              </div>
            </div>

            <div className="bg-white rounded-lg shadow p-6">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-gray-600">Total Margin</p>
                  <p className="text-2xl font-bold text-green-600">
                    ${analytics.totalMargin.toLocaleString()}
                  </p>
                  <p className="text-xs text-gray-500">
                    {analytics.averageMarginPercentage.toFixed(1)}% avg
                  </p>
                </div>
                <div className="bg-blue-100 p-3 rounded-full">
                  <TrendingUp className="text-blue-600" size={24} />
                </div>
              </div>
            </div>

            <div className="bg-white rounded-lg shadow p-6">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-gray-600">Active Loads</p>
                  <p className="text-2xl font-bold text-gray-900">{loads.length}</p>
                  <p className="text-xs text-gray-500">
                    {(analytics.loadsByStatus as any).in_transit || 0} in transit
                  </p>
                </div>
                <div className="bg-purple-100 p-3 rounded-full">
                  <Truck className="text-purple-600" size={24} />
                </div>
              </div>
            </div>

            <div className="bg-white rounded-lg shadow p-6">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-gray-600">Active Carriers</p>
                  <p className="text-2xl font-bold text-gray-900">
                    {carriers.filter((c) => c.status === 'approved').length}
                  </p>
                  <p className="text-xs text-gray-500">{carriers.length} total</p>
                </div>
                <div className="bg-yellow-100 p-3 rounded-full">
                  <Users className="text-yellow-600" size={24} />
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Tabs */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="border-b border-gray-200">
          <nav className="-mb-px flex space-x-8">
            {['loads', 'carriers', 'documents', 'analytics'].map((tab) => (
              <button
                key={tab}
                onClick={() => setActiveTab(tab as any)}
                className={`${
                  activeTab === tab
                    ? 'border-blue-500 text-blue-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                } whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm capitalize`}
              >
                {tab}
              </button>
            ))}
          </nav>
        </div>
      </div>

      {/* Content */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
        {/* Loads Tab */}
        {activeTab === 'loads' && (
          <div className="bg-white rounded-lg shadow overflow-hidden">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Load ID
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Customer
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Route
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Carrier
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Status
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Rate
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Margin
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {loads.map((load) => (
                  <tr key={load.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                      {load.id}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {load.customerName}
                    </td>
                    <td className="px-6 py-4 text-sm text-gray-900">
                      <div>
                        {load.pickupLocation.city}, {load.pickupLocation.state}
                      </div>
                      <div className="text-gray-500">
                        → {load.deliveryLocation.city}, {load.deliveryLocation.state}
                      </div>
                      <div className="text-xs text-gray-400">{load.distance} miles</div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {load.carrierName || 'Unassigned'}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span
                        className={`px-2 py-1 text-xs font-semibold rounded-full ${getStatusColor(
                          load.status
                        )}`}
                      >
                        {load.status.replace('_', ' ').toUpperCase()}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      ${load.customerRate.toLocaleString()}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm">
                      {load.margin ? (
                        <div>
                          <div className="text-green-600 font-semibold">
                            ${load.margin.toLocaleString()}
                          </div>
                          <div className="text-xs text-gray-500">
                            {load.marginPercentage?.toFixed(1)}%
                          </div>
                        </div>
                      ) : (
                        <span className="text-gray-400">—</span>
                      )}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      <div className="flex gap-2">
                        <button
                          onClick={() => handleGenerateDocument('rate_confirmation', load)}
                          className="text-blue-600 hover:text-blue-800 text-xs"
                          title="Generate Rate Confirmation"
                        >
                          RC
                        </button>
                        <button
                          onClick={() => handleGenerateDocument('bol', load)}
                          className="text-green-600 hover:text-green-800 text-xs"
                          title="Generate BOL"
                        >
                          BOL
                        </button>
                        <button
                          onClick={() => handleGenerateDocument('invoice', load)}
                          className="text-purple-600 hover:text-purple-800 text-xs"
                          title="Generate Invoice"
                        >
                          INV
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {/* Carriers Tab */}
        {activeTab === 'carriers' && (
          <div className="bg-white rounded-lg shadow overflow-hidden">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Company
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    MC# / DOT#
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Contact
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Rating
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Performance
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Insurance
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Status
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {carriers.map((carrier) => (
                  <tr key={carrier.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4 text-sm font-medium text-gray-900">
                      {carrier.companyName}
                    </td>
                    <td className="px-6 py-4 text-sm text-gray-900">
                      <div>MC# {carrier.mcNumber}</div>
                      <div className="text-gray-500">DOT# {carrier.dotNumber}</div>
                    </td>
                    <td className="px-6 py-4 text-sm text-gray-900">
                      <div>{carrier.contactName}</div>
                      <div className="text-gray-500">{carrier.email}</div>
                      <div className="text-gray-500">{carrier.phone}</div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm">
                      <div className="flex items-center">
                        <span className="text-yellow-500 mr-1">⭐</span>
                        <span className="font-semibold">{carrier.rating.toFixed(1)}</span>
                      </div>
                    </td>
                    <td className="px-6 py-4 text-sm text-gray-900">
                      <div>{carrier.totalLoads} loads</div>
                      <div className="text-green-600">{carrier.onTimeDeliveryRate}% on-time</div>
                    </td>
                    <td className="px-6 py-4 text-sm">
                      {carrier.insuranceVerified ? (
                        <div>
                          <div className="flex items-center gap-2">
                            <span className="text-green-600 font-semibold">✓ Verified</span>
                            {carrier.insuranceExpiry &&
                              CarrierVerificationService.isInsuranceExpiringSoon(carrier.insuranceExpiry) && (
                                <span className="px-2 py-0.5 text-xs rounded-full bg-yellow-100 text-yellow-800">Expiring Soon</span>
                              )}
                          </div>
                          <div className="text-xs text-gray-500">
                            Exp: {new Date(carrier.insuranceExpiry).toLocaleDateString()}
                          </div>
                        </div>
                      ) : (
                        <span className="text-red-600">Not Verified</span>
                      )}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span
                        className={`px-2 py-1 text-xs font-semibold rounded-full ${getCarrierStatusColor(
                          carrier.status
                        )}`}
                      >
                        {carrier.status.toUpperCase()}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {/* Documents Tab */}
        {activeTab === 'documents' && (
          <div className="bg-white rounded-lg shadow p-6">
            <h3 className="text-lg font-semibold mb-4">Document Management</h3>
            <div className="space-y-4">
              {loads.map((load) => (
                <div key={load.id} className="border rounded-lg p-4">
                  <div className="flex justify-between items-start mb-3">
                    <div>
                      <h4 className="font-semibold">{load.id}</h4>
                      <p className="text-sm text-gray-600">
                        {load.pickupLocation.city} → {load.deliveryLocation.city}
                      </p>
                    </div>
                    <span
                      className={`px-2 py-1 text-xs font-semibold rounded-full ${getStatusColor(
                        load.status
                      )}`}
                    >
                      {load.status.replace('_', ' ').toUpperCase()}
                    </span>
                  </div>
                  <div className="flex gap-3">
                    <button
                      onClick={() => handleGenerateDocument('rate_confirmation', load)}
                      className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 text-sm"
                    >
                      <FileText size={16} className="inline mr-1" />
                      Rate Confirmation
                    </button>
                    <button
                      onClick={() => handleGenerateDocument('bol', load)}
                      className="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700 text-sm"
                    >
                      <FileText size={16} className="inline mr-1" />
                      Bill of Lading
                    </button>
                    <button
                      onClick={() => handleGenerateDocument('invoice', load)}
                      className="px-4 py-2 bg-purple-600 text-white rounded hover:bg-purple-700 text-sm"
                    >
                      <FileText size={16} className="inline mr-1" />
                      Invoice
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Analytics Tab */}
        {activeTab === 'analytics' && analytics && (
          <div className="space-y-6">
            {/* Revenue by Customer */}
            <div className="bg-white rounded-lg shadow p-6">
              <h3 className="text-lg font-semibold mb-4">Revenue by Customer</h3>
              <div className="space-y-3">
                {analytics.revenueByCustomer.map((customer) => (
                  <div key={customer.customerId} className="flex justify-between items-center">
                    <span className="font-medium">{customer.customerName}</span>
                    <span className="text-green-600 font-semibold">
                      ${customer.revenue.toLocaleString()}
                    </span>
                  </div>
                ))}
              </div>
            </div>

            {/* Margin Analysis */}
            <div className="bg-white rounded-lg shadow p-6">
              <h3 className="text-lg font-semibold mb-4">Margin Analysis by Load</h3>
              <div className="overflow-x-auto">
                <table className="min-w-full">
                  <thead className="bg-gray-50">
                    <tr>
                      <th className="px-4 py-2 text-left text-sm font-medium text-gray-500">
                        Load ID
                      </th>
                      <th className="px-4 py-2 text-left text-sm font-medium text-gray-500">
                        Margin ($)
                      </th>
                      <th className="px-4 py-2 text-left text-sm font-medium text-gray-500">
                        Margin (%)
                      </th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-200">
                    {analytics.marginByLoad.map((item) => (
                      <tr key={item.loadId}>
                        <td className="px-4 py-2 text-sm">{item.loadId}</td>
                        <td className="px-4 py-2 text-sm text-green-600 font-semibold">
                          ${item.margin.toLocaleString()}
                        </td>
                        <td className="px-4 py-2 text-sm">{item.marginPercentage.toFixed(1)}%</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>

            {/* Load Status Distribution */}
            <div className="bg-white rounded-lg shadow p-6">
              <h3 className="text-lg font-semibold mb-4">Load Status Distribution</h3>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                {Object.entries(analytics.loadsByStatus).map(([status, count]) => (
                  <div key={status} className="text-center p-4 bg-gray-50 rounded">
                    <div className="text-2xl font-bold text-gray-900">{count}</div>
                    <div className="text-sm text-gray-600 capitalize">
                      {status.replace('_', ' ')}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Dialogs */}
      <LoadCreationDialog
        isOpen={showLoadDialog}
        onClose={() => setShowLoadDialog(false)}
        onCreateLoad={handleCreateLoad}
        carriers={carriers}
      />

      <CarrierOnboardingDialog
        isOpen={showCarrierDialog}
        onClose={() => setShowCarrierDialog(false)}
        onAddCarrier={handleAddCarrier}
      />
    </div>
    </>
  );
};

export default FreightBrokerDashboard;
