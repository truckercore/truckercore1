import React from 'react';
import { Driver, Truck } from '../../types';

interface DriverBoardProps {
  drivers: Driver[];
  trucks: Truck[];
}

const DriverBoard: React.FC<DriverBoardProps> = ({ drivers, trucks }) => {
  const getTruck = (truckId?: string) => trucks.find((t) => t.id === truckId);

  const getStatusColor = (status: string) => {
    const colors: { [key: string]: string } = {
      available: 'driver-available',
      assigned: 'driver-assigned',
      'on-route': 'driver-on-route',
      'off-duty': 'driver-off-duty',
    };
    return colors[status] || 'driver-default';
  };

  const getHoursColor = (hours: number) => {
    if (hours < 3) return 'hours-critical';
    if (hours < 5) return 'hours-warning';
    return 'hours-good';
  };

  return (
    <div className="driver-board">
      {drivers.map((driver) => {
        const truck = getTruck(driver.truckId);
        return (
          <div key={driver.id} className={`driver-card ${getStatusColor(driver.status)}`}>
            <div className="driver-main">
              <div className="driver-avatar">
                {driver.name
                  .split(' ')
                  .map((n) => n[0])
                  .join('')}
              </div>
              <div className="driver-info">
                <h4>{driver.name}</h4>
                <p className="driver-license">{driver.licenseNumber}</p>
                <p className="driver-contact">📞 {driver.phone}</p>
              </div>
              <div className={`status-indicator ${getStatusColor(driver.status)}`}>
                {driver.status.replace('-', ' ').toUpperCase()}
              </div>
            </div>

            {driver.currentLocation && (
              <div className="driver-location">
                <span className="location-icon">📍</span>
                <span>
                  {driver.currentLocation.city}, {driver.currentLocation.state}
                </span>
              </div>
            )}

            <div className="driver-stats">
              <div className="stat">
                <span className="stat-label">Hours Remaining</span>
                <span className={`stat-value ${getHoursColor(driver.hoursRemaining)}`}>{driver.hoursRemaining}h</span>
              </div>
              {truck && (
                <div className="stat">
                  <span className="stat-label">Truck</span>
                  <span className="stat-value">{truck.truckNumber}</span>
                </div>
              )}
            </div>

            {truck && (
              <div className="truck-info">
                <span className="truck-type">{truck.type}</span>
                <span className="truck-capacity">{(truck.capacity / 1000).toFixed(0)}k lbs</span>
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
};

export default DriverBoard;
