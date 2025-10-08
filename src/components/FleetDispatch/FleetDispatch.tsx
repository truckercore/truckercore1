import React, { useEffect, useState } from 'react';
import './FleetDispatch.css';
import { Driver, Truck, Load, Assignment } from '../../types';
import LoadList from './LoadList';
import DriverBoard from './DriverBoard';
import AssignmentModal from './AssignmentModal';

const FleetDispatch: React.FC = () => {
  const [loads, setLoads] = useState<Load[]>([]);
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [trucks, setTrucks] = useState<Truck[]>([]);
  const [selectedLoad, setSelectedLoad] = useState<Load | null>(null);
  const [showAssignmentModal, setShowAssignmentModal] = useState(false);
  const [filterStatus, setFilterStatus] = useState<string>('all');
  const [searchTerm, setSearchTerm] = useState('');

  useEffect(() => {
    loadMockData();
  }, []);

  const loadMockData = () => {
    const mockDrivers: Driver[] = [
      {
        id: 'D001',
        name: 'John Smith',
        licenseNumber: 'CDL-12345',
        phone: '555-0101',
        email: 'john.smith@freight.com',
        status: 'available',
        currentLocation: {
          lat: 41.8781,
          lng: -87.6298,
          city: 'Chicago',
          state: 'IL',
        },
        hoursRemaining: 8.5,
        truckId: 'T001',
      },
      {
        id: 'D002',
        name: 'Sarah Johnson',
        licenseNumber: 'CDL-54321',
        phone: '555-0102',
        email: 'sarah.j@freight.com',
        status: 'available',
        currentLocation: {
          lat: 39.7392,
          lng: -104.9903,
          city: 'Denver',
          state: 'CO',
        },
        hoursRemaining: 10,
        truckId: 'T002',
      },
      {
        id: 'D003',
        name: 'Mike Davis',
        licenseNumber: 'CDL-67890',
        phone: '555-0103',
        email: 'mike.d@freight.com',
        status: 'on-route',
        currentLocation: {
          lat: 33.4484,
          lng: -112.074,
          city: 'Phoenix',
          state: 'AZ',
        },
        hoursRemaining: 6.5,
        truckId: 'T003',
      },
    ];

    const mockTrucks: Truck[] = [
      {
        id: 'T001',
        truckNumber: 'TRK-1001',
        type: 'dry-van',
        capacity: 45000,
        status: 'available',
      },
      {
        id: 'T002',
        truckNumber: 'TRK-1002',
        type: 'reefer',
        capacity: 44000,
        status: 'available',
      },
      {
        id: 'T003',
        truckNumber: 'TRK-1003',
        type: 'flatbed',
        capacity: 48000,
        status: 'assigned',
      },
    ];

    const mockLoads: Load[] = [
      {
        id: 'L001',
        loadNumber: 'LD-2025-001',
        status: 'posted',
        origin: {
          address: '123 Warehouse Blvd',
          city: 'Los Angeles',
          state: 'CA',
          zipCode: '90001',
          contactName: 'Tom Wilson',
          contactPhone: '555-1001',
        },
        destination: {
          address: '456 Distribution Center',
          city: 'Dallas',
          state: 'TX',
          zipCode: '75201',
          contactName: 'Mary Brown',
          contactPhone: '555-2001',
        },
        pickupDate: '2025-10-08T08:00:00',
        deliveryDate: '2025-10-10T17:00:00',
        cargo: {
          description: 'Electronics',
          weight: 32000,
          pieces: 24,
          type: 'Palletized',
        },
        rate: 2500,
        distance: 1435,
        requirements: ['Temperature Controlled', 'Team Required'],
        createdBy: 'dispatcher@freight.com',
        createdAt: '2025-10-06T09:00:00',
      },
      {
        id: 'L002',
        loadNumber: 'LD-2025-002',
        status: 'posted',
        origin: {
          address: '789 Industrial Way',
          city: 'Seattle',
          state: 'WA',
          zipCode: '98101',
          contactName: 'Steve Garcia',
          contactPhone: '555-3001',
        },
        destination: {
          address: '321 Commerce St',
          city: 'Portland',
          state: 'OR',
          zipCode: '97201',
          contactName: 'Linda Martinez',
          contactPhone: '555-4001',
        },
        pickupDate: '2025-10-07T10:00:00',
        deliveryDate: '2025-10-08T14:00:00',
        cargo: {
          description: 'Manufacturing Parts',
          weight: 28000,
          pieces: 18,
          type: 'Crated',
        },
        rate: 1200,
        distance: 173,
        requirements: ['Liftgate Required'],
        createdBy: 'dispatcher@freight.com',
        createdAt: '2025-10-06T10:30:00',
      },
    ];

    setDrivers(mockDrivers);
    setTrucks(mockTrucks);
    setLoads(mockLoads);
  };

  const handleAssignLoad = (load: Load) => {
    setSelectedLoad(load);
    setShowAssignmentModal(true);
  };

  const handleConfirmAssignment = (assignment: Assignment) => {
    setLoads((prev) =>
      prev.map((l) =>
        l.id === assignment.loadId
          ? {
              ...l,
              status: 'assigned',
              assignedDriver: assignment.driverId,
              assignedTruck: assignment.truckId,
            }
          : l,
      ),
    );

    setDrivers((prev) => prev.map((d) => (d.id === assignment.driverId ? { ...d, status: 'assigned' } : d)));
    setTrucks((prev) => prev.map((t) => (t.id === assignment.truckId ? { ...t, status: 'assigned' } : t)));

    setShowAssignmentModal(false);
    setSelectedLoad(null);

    alert(`Load ${selectedLoad?.loadNumber} assigned successfully!`);
  };

  const filteredLoads = loads.filter((load) => {
    const matchesStatus = filterStatus === 'all' || load.status === filterStatus;
    const q = searchTerm.toLowerCase();
    const matchesSearch =
      load.loadNumber.toLowerCase().includes(q) ||
      load.origin.city.toLowerCase().includes(q) ||
      load.destination.city.toLowerCase().includes(q);
    return matchesStatus && matchesSearch;
  });

  return (
    <div className="fleet-dispatch">
      <header className="dispatch-header">
        <h1>🚛 Fleet Manager Dispatch System</h1>
        <div className="header-stats">
          <div className="stat-card">
            <span className="stat-value">{loads.filter((l) => l.status === 'posted').length}</span>
            <span className="stat-label">Available Loads</span>
          </div>
          <div className="stat-card">
            <span className="stat-value">{drivers.filter((d) => d.status === 'available').length}</span>
            <span className="stat-label">Available Drivers</span>
          </div>
          <div className="stat-card">
            <span className="stat-value">{trucks.filter((t) => t.status === 'available').length}</span>
            <span className="stat-label">Available Trucks</span>
          </div>
        </div>
      </header>

      <div className="dispatch-content">
        <div className="loads-section">
          <div className="section-header">
            <h2>Load Board</h2>
            <div className="controls">
              <input
                type="text"
                placeholder="Search loads..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="search-input"
              />
              <select
                value={filterStatus}
                onChange={(e) => setFilterStatus(e.target.value)}
                className="filter-select"
              >
                <option value="all">All Status</option>
                <option value="posted">Posted</option>
                <option value="assigned">Assigned</option>
                <option value="in-transit">In Transit</option>
                <option value="delivered">Delivered</option>
              </select>
            </div>
          </div>
          <LoadList loads={filteredLoads} onAssign={handleAssignLoad} />
        </div>

        <div className="drivers-section">
          <div className="section-header">
            <h2>Driver Status Board</h2>
          </div>
          <DriverBoard drivers={drivers} trucks={trucks} />
        </div>
      </div>

      {showAssignmentModal && selectedLoad && (
        <AssignmentModal
          load={selectedLoad}
          drivers={drivers.filter((d) => d.status === 'available')}
          trucks={trucks.filter((t) => t.status === 'available')}
          onConfirm={handleConfirmAssignment}
          onCancel={() => {
            setShowAssignmentModal(false);
            setSelectedLoad(null);
          }}
        />
      )}
    </div>
  );
};

export default FleetDispatch;
